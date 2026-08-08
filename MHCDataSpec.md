<!--
This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project

SPDX-FileCopyrightText: 2026 Stanford University

SPDX-License-Identifier: MIT
-->

# MHC Data — Sources, Storage & Formats (DRAFT)

| | |
|---|---|
| **Status** | DRAFT v0.6 — for review; open questions in [§7](#7-open-questions). v0.5: stats layer restructured to **one document family per sample type** (metric-major, per-source subtrees) per team direction. v0.6: implemented-vs-proposed separation made explicit. |
| **Date** | 2026-08-06 |
| **Scope** | The reference for all data MHC works with: where it comes from and how it is ingested (§2); how, where, and when it is stored and uploaded (§3); the exact wire/file format of every artifact we produce (§4); the proposed statistics layer (§5); cross-cutting lifecycle (§6). |
| **Audience** | iOS app, Android app (future), Firebase functions/backend, data/research pipeline |
| **Implementation status** | **§2–§4 document the system as it exists and ships today** (verified against code; exceptions tagged FROZEN/DORMANT/PLANNED inline). **§5 is a design proposal — none of it is implemented**: no `healthStats` collection exists, and the dashboard today reads local HealthKit plus per-observation Firestore listeners. |

Status legend: **ACTIVE** (shipping today) · **FROZEN** (code exists, disabled) · **PLANNED** (roadmap, not built) · **DORMANT** (code exists, no caller or consumer) · **PROPOSED** (design only, §5 — nothing exists).

---

## 1. Introduction

My Heart Counts collects health and study data from many origins — HealthKit on iOS, Health Connect on Android (upcoming), server-side wearable APIs (Withings/Fitbit/…, upcoming), SensorKit, in-app manual entry, questionnaires, and active tasks — transforms most of it into FHIR R4, and persists it across three tiers:

| Tier | Holds | Client-queryable? |
|---|---|---|
| **Files** (Cloud Storage) | raw samples from every source — the research record | No |
| **Firestore observation documents** | low-volume, event-like data: questionnaire responses & derived scores, timed-walk results, manual entries, SensorKit batch pointers | Yes (per-document) |
| **Statistics documents** (Firestore, §5) — **PROPOSED, not implemented** | precomputed *inputs* per metric with per-source subtrees: latest-value registers, per-day aggregates, capped low-volume series | would become the primary client read path (today: local HealthKit + per-observation listeners) |

How to read this document: **§2** answers "where does datum X come from and when do we pick it up"; **§3** answers "where does it end up, in which container, on what schedule"; **§4** answers "what do the bytes look like" — every JSON shape, CSV column, and binary field we emit; **§5** specifies the **proposed** statistics layer (design only — nothing implemented); **§6** covers deletion/withdrawal/retention; **§7** lists open questions.

---

## 2. Data Sources & Ingestion

What we collect, from where, when, and under which gates. (Persistence: §3. Byte-level formats: §4.)

### 2.1 iOS / HealthKit — ACTIVE

- **What**: the sample-type set is defined by the study definition (MyHeartCounts-StudyDefinitions, `Study.swift`), not app code: ~40 quantity types (activity, mobility, heart, respiratory, body measurements, dietary subset), the `bloodPressure` correlation, ~20 category types (sleep, stand hours, heart events, mindfulness, reproductive health), workouts, electrocardiogram, stateOfMind, GAD-7 scored assessments, and — where authorized and supported — 9 clinical-record types.
- **Live stream**: SpeziStudy registers `CollectSamples` per type on enrollment → SpeziHealthKit anchored object queries with persisted anchors + HK background delivery. New samples arrive in `handleNewSamples`, deletions in `handleDeletedObjects`. `HKDeletedObject` carries a UUID and type but **no dates** — a fact §5's reconciliation is built around.
- **Historical**: on enrollment (resuming at launch if incomplete), a bulk-export session covers the **last 10 years** of all study types, in per-type batches (1 month for high-volume types, 6 months otherwise). Kill switch `--disableAutomaticBulkHealthExport`.
- **Gate**: signed-in **and** enrolled (`MyHeartCountsStandard+HealthKit.swift:50`); post-unenrollment deliveries ignored.
- ⚠️ **Known gap**: HK-collected **GAD-7 scored assessments have no FHIR mapping** — conversion throws `notSupported` and the samples are dropped with an error log (§4.2.7). GAD-7 data reaches the backend only via the GAD7 questionnaire.

### 2.2 Manual user entry — ACTIVE (HK-backed today) / PLANNED (D5 migration, §5)

- Dashboard "Add Data" sheets: blood pressure, blood glucose, BMI (+ optional weight/height), blood lipids (LDL), plus diet/WHO-5/nicotine via in-app questionnaires from the study bundle.
- Today: lipids and the questionnaire-driven entries write FHIR observations directly to Firestore; BP/glucose/BMI/weight/height are saved **into HealthKit** and ride §2.1.
- **PLANNED**: all manual entries write FHIR observations directly to `HealthObservations_{sampleTypeId}` with a user-entered provenance extension and **no HealthKit write** (HK write access may be denied; uniform behavior regardless of permission — OQ-6). Entry validation ranges (lipids 30–400 mg/dL, systolic 60–250, diastolic 30–150, glucose 40–400, height 0.9–2.5 m, weight 25–450 kg) align with §5.4's clamps.

### 2.3 Questionnaires — ACTIVE

- 15 surveys, scheduled per the study definition (some event-chained, some always-available), captured as FHIR R4 `QuestionnaireResponse` (§4.3.3).
- **Server-side derived ingestion**: a Firestore trigger runs scoring services keyed by canonical questionnaire URL, producing derived FHIR observations (Diet MEPA 0–21, WHO-5 0–25 raw, nicotine category 0–4, LDL parsed from heartRisk) — §4.3.4. Known wart: scores stamp `effectiveDateTime` = processing time (LDL: authored time).
- **App-side derived ingestion**: heartRisk answers (BP pair, second systolic, glucose) are parsed on-device and saved **into HealthKit** — shares the HK-write dependency; part of OQ-6.

### 2.4 Active tasks — ACTIVE

- **Timed walk/run tests** (6MWT, 12-minute run): pedometer-filled result (steps, distance, duration, kind) at completion (§4.3.2). CoreMotion side-streams (altimeter, pedometer events) stay in memory, **not persisted**. A paired watchOS workout session runs during the test; its samples arrive via §2.6.
- **ECG**: recorded on Apple Watch; the app detects the new `HKElectrocardiogram` via a HK query and completes the task. Voltages + symptoms ride §2.1 (§4.2.5).

### 2.5 SensorKit — ACTIVE

11 sensors (visits, on-wrist state, device usage, ECG, wrist temperature, heart rate, pedometer, ambient light, accelerometer, ambient pressure, PPG), fetched via anchored queries after the OS's 24 h quarantine, at launch (~1 s delay) + a dedicated `BGProcessingTask` (network + complete data protection). Up to 3 sensors concurrently on Pro devices, else 1. Deterministic content-derived sample UUIDs make re-fetches idempotent (§4.5.1). Kill switch `--disableSensorKitUpload`. Research-only; never a dashboard input.

### 2.6 Apple Watch — ACTIVE (no direct uploads)

The watch app collects and uploads nothing itself. Workout sessions during timed tests write to HealthKit; samples reach the iPhone via native HK sync and enter §2.1.

### 2.7 Android / Health Connect — PLANNED

Same conceptual shape as §2.1 against Health Connect; changes-token diffs as the ingestion signal; HC's ~30-day retention bounds the live window. Contributes to the stats layer per §5.5.

### 2.8 Server-side providers (Withings, Fitbit, Oura, …) — PLANNED

Provider API pulls/webhooks, server-side. Raw payloads are appended to file storage (normalized format TBD by the server team); a server contributor folds them into `srv-{provider}` stats documents (§5.5). **No per-sample Firestore documents** — the wearable-integrations branch's `<Provider>Observations_*` write layer is deprecated; its adapters and metric catalog are salvageable. Known provider traps: Withings `value × 10^unit` exponent encoding; Fitbit unit system varying with the `Accept-Language` header.

### 2.9 Account, demographics & environment — ACTIVE

- Onboarding/demographics forms populate SpeziAccount `@AccountKey` fields (DOB, sex at birth, gender identity, race/ethnicity, height/weight, region, income, education, comorbidities, NHS number, study state, preferences).
- Environment values auto-push on scene-active/timezone/locale change: `timeZone`, `language`, `lastActiveDate`, `fcmToken`.
- Field encodings: §4.6.3. Stats relevance: `raceEthnicity` selects BMI banding on-device; `timeZone` is the server contributors' fallback tz.

### 2.10 Other user-generated events — ACTIVE

Signed consent (PDF + metadata, §4.6.1) at onboarding; notification-opened tracking events; user feedback (§4.6.4).

---

## 3. Storage & Upload

Where each stream lands, in which container, when, and by what mechanism. (Exact byte formats: §4.)

### 3.1 Cloud Storage layout (file tier)

```
users/{uid}/liveHealthSamples/{sampleTypeId}_{UUID}.json.zstd        # live HK stream (§3.3)
users/{uid}/historicalHealthSamples/{sampleTypeId}_{UUID}.json.zstd  # 10-year bulk export
users/{uid}/healthDeletions/{sampleTypeId}_{UUID}.csv.zstd           # HK deletion tombstones
users/{uid}/SensorKit/{sensorId}/{UUID}.{csv|json}.zstd | {UUID}.mhcPPG
users/{uid}/consent/{unixSeconds}.pdf
public/mhcStudyBundle.spezistudybundle.aar, public/…                 # study bundle, news (world-readable)
```

Rules: `users/{uid}/**` owner read/write (recursive); `public/**` world-readable; everything else deny. All `users/{uid}/` files die with the account (§6.1).

### 3.2 Firestore layout

```
users/{uid}                                  # account doc: @AccountKey fields (§4.6.3) + server fields
  questionnaireResponses/{id}                # FHIR QuestionnaireResponse (§4.3.3)
  HealthObservations_{sampleTypeId}/{uuid}   # FHIR Observations: timed-walk results, custom score types,
                                             #   manual entries (planned), SensorKit batch pointer pairs
  healthStats/{metricId}[_{YYYY-MM}] + index # PROPOSED statistics layer, does not exist yet (§5)
  notificationBacklog/{id} → notificationHistory/{id}   # server nudge pipeline (§4.6.5)
  notificationTracking/{id}                  # client "opened" events (§4.6.4)
feedback/{uuid}                              # root, create-only (§4.6.4)
questionnaires/{id}                          # root, read-only; unused (bundle is authoritative)
```

Security rules today: one wildcard level — `users/{uid}/{collectionName}/{documentId}`, owner read/write, no content validation. The stats layer adds a `srv-`/`merged` carve-out (§5.7).

Notes on `HealthObservations_{sampleTypeId}`: doc ID = sample UUID; writers are the iOS app (`.directFirestore` strategy: timed-walk results, custom-type entries, batched ≤100/`WriteBatch`), the server scoring services, and SensorKit batch pointer pairs. **Two FHIR dialects coexist per collection** — iOS-written and server-written docs differ systematically (§4.3.5). For HK-typed metrics these collections will contain **manual entries only**; device samples must never be backfilled into them (double-feed risk, §5.6.2). Deletion = status flip to `entered-in-error`; every consumer filters that status.

### 3.3 Upload mechanics & timing

| Stream | Staging | Trigger / cadence | Destination |
|---|---|---|---|
| HK live samples | GRDB SQLite queue (§4.4.1): per-sample zstd FHIR JSON, dedup key `(sampleType, sampleId)` | rows drained once **≥3 whole days old** (enables deletion elision) — every launch + ~6 h `BGProcessingTask` (network) | Storage `liveHealthSamples/` (§4.4.2) via ManagedFileUpload |
| HK deletions | same queue; pending deletion **elides** a not-yet-uploaded matching sample | drained with the live stream | Storage `healthDeletions/` (§4.4.3) |
| HK historical export | resumable bulk-export session, retrying, concurrency 2–4 | starts on enroll, runs to completion | Storage `historicalHealthSamples/` (§4.4.4); clinical records re-routed through the live path |
| Unmapped-type fallback | none | immediate | Storage `liveHealthSamples/` (§4.4.2 quirk) |
| Direct-Firestore observations | none | immediately on save/completion | Firestore `HealthObservations_*` |
| Questionnaire responses | none | immediately on completion | Firestore `questionnaireResponses/` |
| SensorKit | none (OS-side 24 h quarantine) | launch + BG task; per batch: payload file + Firestore doc pair | Storage `SensorKit/{sensorId}/` + Firestore pointers (§4.5) |
| Consent PDF | ManagedFileUpload staging dir | on signing | Storage `consent/` (§4.6.1) |
| Stats documents — **PROPOSED** | none (local hash-diff state) | §5.5: UI-cadence (foreground, debounced 30–120 s) + ~6 h BG task + weekly sweep | Firestore `healthStats/` |

**ManagedFileUpload transport** (used by all Storage uploads): staging root `Documents/ManagedFileUploading/{categoryId}/`; the temp file is *moved* in, uploaded with contentType `application/octet-stream` (no customMetadata except consent), deleted locally on success; failures stay staged and retry at every launch. No upload without a signed-in account.

**Timing consequence**: the ≥3-day staging drain means server-side views of raw iOS data lag by days *by design*. The proposed stats layer would be exempt: device-computed contributions (§5) would be written straight from HealthKit at UI cadence, never waiting on the file pipeline.

### 3.4 Server-side processing of uploads

| Function | Status | Role |
|---|---|---|
| Questionnaire-response scoring trigger | **ACTIVE** | derived score observations (§4.3.4) into `HealthObservations_MHCCustom*` |
| `onArchivedLiveHealthSampleUploaded` (Storage→Firestore per-sample fan-out) | **FROZEN** since 2026-05-06 (cost) | superseded by the stats layer for client serving; GCS backlog accumulating (OQ-7; `srv-ios-backfill` reserved, §5.1) |
| `deleteHealthSamples` callable + retry queue | callable ACTIVE, queue worker FROZEN, no iOS caller | entered-in-error marking (§6.2) |
| Provider ingestion (files → `srv-*` stats docs) | PLANNED | §2.8 / §5.5 |
| Nudge planning/sending, user-deletion sweep | ACTIVE | §4.6.5, §6.1 |

### 3.5 What is deliberately not persisted

Dashboard aggregates and CVH scores today (recomputed per render — the gap §5 closes); timed-test CoreMotion side-streams; watch-local data beyond HK sync; achievements state (separate `achievementTracking` doc, out of scope).

### 3.6 Master table

| Data kind | Source | Trigger | Format (§4) | Destination | Client-queryable via |
|---|---|---|---|---|---|
| HK samples (all study types) | 2.1 | background delivery / anchored queries | FHIR Observation → zstd JSON array (§4.2, §4.4.2) | Storage `liveHealthSamples/` | today: local HealthKit only; proposed: stats docs (§5) |
| HK history (10 y) | 2.1 | enrollment | same, fewer extensions (§4.4.4) | Storage `historicalHealthSamples/` | — (research archive) |
| HK deletions | 2.1 | HK tombstones | CSV zstd (§4.4.3) | Storage `healthDeletions/` | — (no consumer today; proposed: absorbed by stats recompute) |
| Timed walk/run results | 2.4 | task completion | FHIR Observation (§4.3.2) | Firestore `HealthObservations_…TimedWalkingTest…` | per-doc reads |
| Manual entries | 2.2 | Add-Data sheets | FHIR Observation (§4.3.1) | today: HealthKit for HK types, Firestore for custom types; planned: Firestore `HealthObservations_{sampleTypeId}` for all | today: HK queries + custom-type listeners; proposed: merge source `manual` (§5.6) |
| Questionnaire responses | 2.3 | task completion | FHIR QuestionnaireResponse (§4.3.3) | Firestore `questionnaireResponses/` | server scoring trigger |
| Server questionnaire scores | 2.3 | Firestore trigger | FHIR Observation, server dialect (§4.3.4) | Firestore `HealthObservations_MHCCustom…` | existing listeners |
| SensorKit streams | 2.5 | launch + BG task (24 h quarantine) | per-sensor CSV/JSON/binary + FHIR pointer pair (§4.5) | Storage `SensorKit/` + Firestore pointers | — (research only) |
| Provider data — PLANNED | 2.8 | server pull/webhook | normalized files (TBD) | Storage + `srv-*` stats subtrees (proposed) | stats docs (proposed) |
| Demographics/env | 2.9 | onboarding + auto-push | Firestore fields (§4.6.3) | `users/{uid}` doc | AccountDetails |
| Consent / feedback / notification events | 2.9–2.10 | resp. flows | §4.6.1, §4.6.4 | Storage & Firestore | resp. features |
| Precomputed stats — **PROPOSED** | §5 | §5.5 protocol | Firestore maps (§5.2) | `users/{uid}/healthStats/*` | would become the primary dashboard read path |

---

## 4. Format Reference

The exact wire/file format of every artifact MHC produces. Verified against the working tree, the Spezi checkouts the app builds against, and FHIRModels 0.9.1; citations point at the encoders.

### 4.1 Conventions & primitives

**zstd**: every `.zstd` artifact is a **single raw zstd frame** — no tar/gzip wrapper, no dictionary; default level 3; produced via one-shot `ZSTD_compressCCtx`, so the frame header **carries the decompressed size** (standard `0xFD2FB528` magic). MHC's own decoder *requires* the content-size field (`SpeziFoundation/Compression/Zstd.swift`).

**JSON encoders** (three variants in play):
- Staged live samples: `JSONEncoder` with `.withoutEscapingSlashes`, per-sample; files then assembled by **string concatenation** `"[" + join(",") + "]"` (§4.4.2).
- Fallback & historical uploads: plain `JSONEncoder().encode([…])` — forward slashes escaped as `\/`.
- Key order is nondeterministic everywhere (no `.sortedKeys`). Decimals encode as JSON numbers.

**Time encodings** (three coexist; know which you're reading):
1. FHIR dateTime/Instant strings: `YYYY-MM-DDThh:mm:ss[.fff…]±hh:mm` (or `Z`); local device offset; fractional seconds pass through a Double division, so up to 15 fraction digits with float artifacts are possible.
2. CSV timestamps: **epoch seconds as Swift `Double` description** (e.g. `1754468122.531`) — never ISO.
3. SensorKit docNames / consent filenames: UTC `ISO8601Format()` (`Z`, second precision) / whole Unix seconds.

**UUID casing**: iOS-written IDs (doc IDs, FHIR `id`) are **uppercase** `UUID().uuidString`; server-written (functions `randomUUID()`) are **lowercase** (nudge docs are uppercased). Casing is a reliable writer fingerprint.

**Coding systems**:

| System URL | Used for |
|---|---|
| `http://developer.apple.com/documentation/healthkit` (**http**) | HK type codings (`code.coding`) |
| `https://developer.apple.com/documentation/healthkit/<lowercased-type-name>` (**https**) | HK enum *value* codings; nested type names collapse to the last component (`HKElectrocardiogram.Classification` → `…/classification`); `code` = decimal rawValue as string |
| `https://developer.apple.com/documentation/sensorkit` | SensorKit sensor codings (`code` = sensor id) |
| `https://spezi.stanford.edu` | MHC custom sample types; `watchWristLocation`/`watchCrownOrientation` components |
| `http://loinc.org`, `http://snomed.info/sct`, `http://unitsofmeasure.org` (UCUM), `urn:oid:2.16.840.1.113883.6.24` (MDC/ECG) | standard codings |

**MHC FHIR extension registry** (all URLs):

| URL | Value / children |
|---|---|
| `https://bdh.stanford.edu/fhir/defs/sourceDevice` | children `name, manufacturer, model, hardwareVersion, firmwareVersion, softwareVersion, localIdentifier, udiDeviceIdentifier` (valueString each; non-nil only); absent when `HKDevice` nil |
| `https://bdh.stanford.edu/fhir/defs/sourceRevision` | child `source` (children `name`, `bundleIdentifier`), then `version`, `productType`, `OSVersion` (valueString; non-nil only) |
| `https://bdh.stanford.edu/fhir/defs/metadata` | one child per HK metadata key (`…/metadata/<key>`); String→valueString, enum-NSNumber→valueCoding (16 known keys), Bool→valueBoolean, number→valueDecimal, Date→valueDateTime, HKQuantity→valueQuantity (~20 known keys); unknown types silently skipped |
| `https://bdh.stanford.edu/fhir/defs/sampleUploadTimeZone` | valueString = IANA tz at conversion time |
| `https://myheartcounts.stanford.edu/fhir/StructureDefinition/study-enrollment` | children `…/study-id` (valueString UUID), `…/study-revision` (valueInteger); omitted when not enrolled |
| `https://bdh.stanford.edu/fhir/defs/HealthKitSampleID` | valueId; clinical-record passthrough only |
| `https://bdh.stanford.edu/fhir/defs/SensorKit/sourceDevice` | children `model, name, systemName, systemVersion, productType` (valueString) |
| `https://bdh.stanford.edu/fhir/defs/SensorKit/WristTemp/algorithmVersion`; `…/SensorKit/Visits/*`; `…/SensorKit/DeviceUsage/*` | per-sensor payload extensions (§4.5) |

Extension application uses `.replace` semantics (same-URL extensions are replaced, never duplicated). **Server-written observations use a flat variant** of the sourceRevision family (full URL per entry, not nested) — §4.3.4.

### 4.2 FHIR encodings of HealthKit samples

**Pipeline**: `HealthObservation.turnIntoFHIRResource` routes: ECG → special builder with fetched symptoms+voltages; clinical records → provider-FHIR passthrough **with a wrapper envelope**; everything else → SpeziHealthKitFHIR `.default` mapping. Output is bare FHIR resource JSON in all cases **except clinical records**, which serialize as `{"version": "R4"|"DSTU2", "resource": {…}}` — the only wrapped payload in the pipeline, and it coexists with bare Observations inside `liveHealthSamples` files.

**Common Observation skeleton** (every HK sample): `status: "final"`; `id` = sample UUID (uppercase); `identifier: [{"id": "<uuid>", "value": "<uuid>"}]`; `effectiveDateTime` when start==end else `effectivePeriod{start,end}` (tz from the sample's `HKMetadataKeyTimeZone` if valid, else device tz); `issued` = Instant at **conversion time** (for staged data this precedes upload by ≥3 days); extensions in order: `sourceDevice`, `sourceRevision`, `metadata`, `sampleUploadTimeZone`, `study-enrollment`.

Full extension-set example:

```json
"extension": [
  { "url": "https://bdh.stanford.edu/fhir/defs/sourceDevice", "extension": [
      {"url": ".../sourceDevice/name", "valueString": "Apple Watch"},
      {"url": ".../sourceDevice/manufacturer", "valueString": "Apple Inc."},
      {"url": ".../sourceDevice/model", "valueString": "Watch"},
      {"url": ".../sourceDevice/hardwareVersion", "valueString": "Watch7,2"},
      {"url": ".../sourceDevice/softwareVersion", "valueString": "11.2"} ]},
  { "url": "https://bdh.stanford.edu/fhir/defs/sourceRevision", "extension": [
      { "url": ".../sourceRevision/source", "extension": [
          {"url": ".../source/name", "valueString": "Lukas's Apple Watch"},
          {"url": ".../source/bundleIdentifier", "valueString": "com.apple.health.XXXX"} ]},
      {"url": ".../sourceRevision/version", "valueString": "11.2"},
      {"url": ".../sourceRevision/productType", "valueString": "Watch7,2"},
      {"url": ".../sourceRevision/OSVersion", "valueString": "11.2.0"} ]},
  { "url": "https://bdh.stanford.edu/fhir/defs/metadata", "extension": [
      {"url": ".../metadata/HKTimeZone", "valueString": "America/Los_Angeles"},
      {"url": ".../metadata/HKMetadataKeyHeartRateMotionContext",
       "valueCoding": {"system": "https://developer.apple.com/documentation/healthkit/hkheartratemotioncontext", "code": "1", "display": "sedentary"}} ]},
  { "url": "https://bdh.stanford.edu/fhir/defs/sampleUploadTimeZone", "valueString": "America/Los_Angeles" },
  { "url": "https://myheartcounts.stanford.edu/fhir/StructureDefinition/study-enrollment", "extension": [
      {"url": ".../study-enrollment/study-id", "valueString": "5D464372-C9A3-4018-A789-47149D934BFC"},
      {"url": ".../study-enrollment/study-revision", "valueInteger": 40} ]}
]
```

#### 4.2.1 HKQuantitySample

`code.coding` = mapping's standard codings (LOINC first, SNOMED where present) **followed by** the HK identifier coding. One `valueQuantity` with the mapping's UCUM system/code + human unit string; system/code omitted together for unit-less counts (steps, flights, falls, …). Unmapped quantity types throw and the sample is dropped.

```json
{ "resourceType": "Observation",
  "id": "76A331B4-0F40-45A4-A213-01F1AB5B0EDA",
  "identifier": [{"id": "76A331B4-…", "value": "76A331B4-…"}],
  "status": "final",
  "code": {"coding": [
    {"system": "http://loinc.org", "code": "8867-4", "display": "Heart rate"},
    {"system": "http://snomed.info/sct", "code": "364075005", "display": "Heart rate"},
    {"system": "http://developer.apple.com/documentation/healthkit", "code": "HKQuantityTypeIdentifierHeartRate", "display": "Heart Rate"} ]},
  "effectiveDateTime": "2026-08-05T09:41:12.53-07:00",
  "issued": "2026-08-06T10:15:23.417-07:00",
  "valueQuantity": {"system": "http://unitsofmeasure.org", "code": "/min", "unit": "beats/minute", "value": 62},
  "extension": [ "…full MHC extension set…" ] }
```

Unit highlights: bodyMass kg; height cm; bloodGlucose mg/dL; BP `mm[Hg]`/"mmHg"; temperatures Cel; SpO₂/bodyFat/walking-asymmetry `%`; HRV-SDNN ms; vo2Max mL/kg/min; distances m; energy kcal; speeds m/s; respiratoryRate `/min` "breaths/minute"; stepCount "steps" (no UCUM).

⚠️ **Percent scaling**: HK stores percent-typed values as 0…1; the built mapping **multiplies by 100** — wire values are 0…100 with unit `%`. (Flagged in the 2026-08 FHIRModels branch review; documented here as current wire behavior.)

#### 4.2.2 HKCategorySample

`code.coding` = single HK identifier coding. Value encoding by type:
- Enum-valued types (sleepAnalysis, appleStandHour, symptom severities, menstrualFlow, test results, …): `valueCodeableConcept` with one coding — system = the https enum-value system, `code` = **integer rawValue as string**, display = generated lowercase name. sleepAnalysis raw values: inBed=0, asleepUnspecified=1, awake=2, asleepCore=3, asleepDeep=4, asleepREM=5.
- No-value types (mindfulSession, irregularHeartRhythmEvent, pregnancy, …): `valueString` = the category type identifier itself.
- Metadata-derived components: high/lowHeartRateEvent → HR-threshold component; lowCardioFitnessEvent → vo2Max components; menstrualFlow → cycle-start boolean component; sexualActivity → protection-used boolean component.

```json
{ "code": {"coding": [{"system": "http://developer.apple.com/documentation/healthkit", "code": "HKCategoryTypeIdentifierSleepAnalysis", "display": "Sleep Analysis"}]},
  "effectivePeriod": {"start": "2026-08-05T01:12:00-07:00", "end": "2026-08-05T02:40:30-07:00"},
  "valueCodeableConcept": {"coding": [{"system": "https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis", "code": "5", "display": "asleep REM"}]} }
```

#### 4.2.3 HKCorrelation (bloodPressure)

`category` = `vital-signs`; `code.coding` = LOINC `35094-2` + `85354-9`; **no top-level value** — one `component` per contained quantity sample (full coding list each; systolic LOINC `8480-6`, diastolic `8462-4`, UCUM `mm[Hg]`). ⚠️ Component order comes from a Set — **nondeterministic; match components by code, never index**. Only bloodPressure and food correlations are mapped.

#### 4.2.4 HKWorkout

Observation modeled on the HL7 physical-activity IG: `category` = `activity` + `PhysicalActivity` (pa-temporary-codes); `code.coding` = `{healthKit, "HKWorkout"}` + LOINC `73985-4`; `valueCodeableConcept` single coding `{healthKit, "<camelCase activity>"}` (no display; note `cooldown → "coolDown"`); duration implied by `effectivePeriod`; energy/distance arrive as separate quantity Observations; workout metadata (METs, weather, …) in the `metadata` extension.

#### 4.2.5 HKElectrocardiogram

`code.coding` = `{healthKit, "HKElectrocardiogram"}` + MDC `{urn:oid:2.16.840.1.113883.6.24, "131328", "MDC_ECG_ELEC_POTL"}`; `category` = `procedure`. Components in fixed order: ① numberOfVoltageMeasurements (valueQuantity, unit "measurements", no UCUM) ② samplingFrequency (Hz, if present) ③ classification (valueCodeableConcept; rawValues: notSet=0, sinusRhythm=1, atrialFibrillation=2, inconclusiveLowHeartRate=3, inconclusiveHighHeartRate=4, inconclusivePoorReading=5, inconclusiveOther=6, unrecognized=100) ④ averageHeartRate (if present) ⑤ symptomsStatus (notSet=0, none=1, present=2); then ⑥ one component per queried symptom (7 types; severity valueCodeableConcept, rawValues 0–4) — ⚠️ order nondeterministic — then ⑦ voltage batches:

```json
{ "code": {"coding": [{"system": "urn:oid:2.16.840.1.113883.6.24", "code": "131329", "display": "MDC_ECG_ELEC_POTL_I"}]},
  "valueSampledData": {
    "origin": {"system": "http://unitsofmeasure.org", "code": "uV", "unit": "uV", "value": 0},
    "period": 1.953125, "dimensions": 1,
    "data": "12.345 13.001 -4.220 …" } }
```

`SampledData` per ~10 s batch; values in **µV**, `%.3f`, space-joined, time-sorted; `period` = ms between samples (`1000/frequency`); Apple Watch ECG ≈ 512 Hz × 30 s = 15 360 values across 3–4 components. ⚠️ **Historical-export ECGs carry components ①–⑤ only** — no voltages, no symptoms (§4.4.4).

#### 4.2.6 HKStateOfMind

Identifier `HKDataTypeIdentifierStateOfMind`; `category` = `survey`; components in order: `HKStateOfMindKind` (valueString `"momentary emotion"`/`"daily mood"`), `HKStateOfMindValence` (**valueQuantity with only `value`**, −1…+1), `HKStateOfMindValenceClassification` (valueString, e.g. `"slightly pleasant"`), then one valueString component per label (lowercase, e.g. `"grateful"`) and per association (camelCase, e.g. `"selfCare"`).

#### 4.2.7 GAD-7 scored assessments — NOT CONVERTIBLE

`HKGAD7Assessment` has no `FHIRObservationBuildable` conformance in the built Spezi revision → `resource()` throws `notSupported` → **samples are dropped at upload with an error log**. GAD-7 reaches the backend only as a QuestionnaireResponse. (Tracked gap.)

#### 4.2.8 HKClinicalRecord passthrough

- Envelope: `{"version": "R4"|"DSTU2", "resource": {…provider FHIR JSON…}}` — decided by the record's FHIR release; both passed through natively. **The only wrapped payload shape in the pipeline.**
- Added: `{"url": "https://bdh.stanford.edu/fhir/defs/HealthKitSampleID", "valueId": "<record uuid>"}` + the sourceRevision extension family describing the **provider gateway** that wrote the record. Attachments (document/diagnostic categories) are base64-embedded into `DocumentReference.content[].attachment.data` / `DiagnosticReport.presentedForm[].data`.
- **Not** applied: metadata/sampleUploadTimeZone/study-enrollment/sourceDevice; `id`/`identifier`/`issued`/`effective` stay whatever the provider emitted.

### 4.3 MHC-native FHIR shapes (Firestore observation documents)

#### 4.3.1 Custom quantity samples (iOS-written)

Types: `MHCCustomSampleTypeBloodLipidMeasurement` (mg/dL), `…DietMEPAScore`, `…WHO5Score`, `…NicotineExposure` (count). Destination: `users/{uid}/HealthObservations_{typeId}/{UUID-uppercase}`.

- bloodLipids: dual coding LOINC `18262-6` + spezi; `valueQuantity{system: loinc, code: 18262-6, unit: "mg/dL"}`.
- count types: single spezi coding; ⚠️ `valueQuantity.system` = **the spezi URL** (not UCUM), `code` = the type id, `unit: "count"`.
- `identifier[0]` carries **only an element `id`** (no `value`) — differs from HK samples.
- **No `subject` field.** The server's zod decoder requires `subject`, so iOS-written docs in these collections fail that parse (§4.3.5).
- Extensions: sampleUploadTimeZone + study-enrollment + nested sourceRevision (app as source: name "My Heart Counts", bundleId `edu.stanford.MyHeartCounts`, version `"x.y (build)"`; `productType` omitted).

#### 4.3.2 Timed walking test result (iOS-written)

Destination `…/HealthObservations_MHCHealthObservationTimedWalkingTestResultIdentifier/{UUID}`. `code.coding`: LOINC `62619-2` (6MWT — **only for the six-minute walk**) + `55413-9` (pedometer panel, always). Components (codes have no display; ⚠️ `valueQuantity.system/code` = the LOINC code, not UCUM):

| Component LOINC | Value |
|---|---|
| `64098-7` (6MWT only) | distance, unit "m" |
| `55423-8` | steps, unit "count" |
| `55430-3` | distance, unit "m" |
| `55411-3` | duration, unit "min" (= seconds/60) |
| `73985-4` | valueCodeableConcept: `LA11834-1` walking / `LA11836-6` running |

`effectivePeriod` = test start→end; extensions as §4.3.1.

#### 4.3.3 QuestionnaireResponse (iOS-written)

Destination `users/{uid}/questionnaireResponses/{docId}`; docId = response identifier if present, else fresh UUID — in practice **always a fresh uppercase UUID that differs from the resource's inner `id`**. Fields: `resourceType`, `status: "completed"`, `id`, `authored`; `questionnaire` force-set to the canonical URL (`https://myheartcounts.stanford.edu/fhir/survey/{dietScore|who5|nicotineExposure|heartRisk|…}`); `item[].{linkId, answer[]{valueBoolean|valueCoding|valueQuantity|valueInteger|valueDecimal|valueString}}`, nested items possible.

#### 4.3.4 Server-written score observations (Cloud Functions dialect)

Destination `users/{uid}/HealthObservations_MHCCustomSampleType…/{lowercase-uuid}` (doc id = resource id). Shape:

```json
{ "resourceType": "Observation",
  "id": "d2a4c0de-6a3f-44a1-9c1e-2f4b5a6c7d8e",
  "status": "final",
  "subject": { "reference": "user/<uid>" },
  "code": { "text": "WHO-5 Well-Being Score",
    "coding": [{ "system": "https://spezi.stanford.edu", "code": "MHCCustomSampleTypeWHO5Score", "display": "WHO-5 Well-Being Score" }] },
  "valueQuantity": { "value": 17, "unit": "count", "system": "http://unitsofmeasure.org", "code": "{count}" },
  "effectiveDateTime": "2026-08-06T20:29:17.542Z",
  "issued": "2026-08-06T20:29:17.545Z",
  "derivedFrom": [{ "reference": "QuestionnaireResponse/<docId>" }],
  "extension": [
    { "url": "https://bdh.stanford.edu/fhir/defs/sampleUploadTimeZone", "valueString": "<server tz>" },
    { "url": "https://bdh.stanford.edu/fhir/defs/sourceRevision/source/name", "valueString": "My Heart Counts Firebase" },
    { "url": "https://bdh.stanford.edu/fhir/defs/sourceRevision/source/bundleIdentifier", "valueString": "edu.stanford.MyHeartCounts" },
    { "url": "https://bdh.stanford.edu/fhir/defs/sourceRevision/version", "valueString": "<functions package version>" },
    { "url": "https://bdh.stanford.edu/fhir/defs/sourceRevision/OSVersion", "valueString": "<node version>" } ] }
```

Scoring services: Diet (21 booleans → 0–21), WHO-5 (5 coded answers `all-of-the-time`=5 … `at-no-time`=0 → 0–25 **raw**, not ×4), Nicotine (coded smoking status → 0–4; two producers: nicotine survey + heartRisk), heartRisk-LDL (`valueQuantity`→`valueInteger`→`valueDecimal`→`parseFloat(valueString)`, dual coding LOINC 18262-6 + spezi with display `"LDL Cholesterol"`, **no sourceRevision extensions**, `effectiveDateTime` = questionnaire `authored`). Others stamp `effectiveDateTime` = **scoring time** (UTC-`Z`, ms precision). Diet `domainScores` are computed but **dropped** (nothing writes `users/{uid}/scores`).

#### 4.3.5 The two-dialect problem (decoder-critical)

`HealthObservations_MHCCustomSampleType*` collections contain **both** iOS-written and server-written docs, which differ systematically:

| | iOS-written | Server-written |
|---|---|---|
| doc ID / `id` | uppercase UUID | lowercase UUID |
| `subject` | absent | `{"reference": "user/<uid>"}` |
| `identifier` | `[{"id": …}]` | absent |
| sourceRevision ext | nested tree | flat URL-per-entry |
| dates | local offset, fractional | UTC `Z`, ms |
| count `valueQuantity.system` | spezi URL | UCUM `{count}` |
| `sampleUploadTimeZone` | user's tz | **server's** tz |

Consequences already observed in code: the server's zod parse requires `subject` (iOS docs fail it); the nicotine service sorts by `effectiveDateTime` **string** — lexicographic, correct only for uniform UTC-`Z` strings; server round-trips drop `valueCodeableConcept` components. Any new consumer must handle both dialects.

### 4.4 HealthKit container/file formats

#### 4.4.1 On-device staging DB (not uploaded itself)

`Documents/healthObservations.sqlite3`, GRDB, STRICT tables:

```sql
CREATE TABLE pendingSamples (
  id         BLOB PRIMARY KEY NOT NULL,   -- record UUID, 16 raw bytes
  timestamp  TEXT NOT NULL,               -- "yyyy-MM-dd HH:mm:ss.SSS" UTC (GRDB default; NOT ISO-8601 despite the comment)
  sampleType TEXT NOT NULL,               -- e.g. "HKQuantityTypeIdentifierStepCount"
  sampleId   BLOB NOT NULL,               -- HK sample UUID, 16 raw bytes
  fhirJson   BLOB NOT NULL,               -- zstd frame → ONE FHIR resource JSON
  UNIQUE (sampleType, sampleId) ON CONFLICT REPLACE
) STRICT;
CREATE TABLE pendingDeletions ( id BLOB PK, timestamp TEXT, sampleType TEXT, sampleId BLOB,
  UNIQUE (sampleType, sampleId) ON CONFLICT REPLACE ) STRICT;
```

`fhirJson` decompresses to a bare FHIR resource — except clinical records, which hold the `{"version":…, "resource":…}` wrapper. Inserting a deletion **deletes matching pending samples** instead of recording it (elision).

#### 4.4.2 `liveHealthSamples/{sampleTypeId}_{UUID}.json.zstd`

One file per sample type per drain. zstd frame → UTF-8 JSON **array** assembled by string concatenation (no whitespace). Elements: bare FHIR resources of one HK type — or `{"version":…, "resource":…}` wrappers for clinical-record types. Element order = SQLite fetch order (not guaranteed). Second producer, same destination: unmapped-type fallback uploads a plain `JSONEncoder` array immediately (slashes escaped `\/`) — same filename pattern.

#### 4.4.3 `healthDeletions/{sampleTypeId}_{UUID}.csv.zstd`

zstd → UTF-8 CSV; separator `,`, terminator `\n` (every row), RFC-4180-style quoting (only when needed; never needed for these columns), **header row present**. Exact shape:

```
sampleType,sampleId,timestamp
HKQuantityTypeIdentifierStepCount,1E2D3C4B-5A69-4788-97A6-B5C4D3E2F101,1754468122.531
```

`sampleId` uppercase UUID; `timestamp` **epoch seconds as Double** (deletion-staged time, not sample time). One file per sample type per drain. No consumer today (§3.4).

#### 4.4.4 `historicalHealthSamples/{sampleTypeId}_{UUID}.json.zstd`

Proper `JSONEncoder().encode([ResourceProxy])` array (slashes escaped), one HK type per file. ⚠️ Built with mapping defaults only: **no `sampleUploadTimeZone`, no `study-enrollment` extensions; ECGs without voltages/symptoms**; `issued` = processing time. Clinical records never appear here (re-routed through the live path).

### 4.5 SensorKit formats

#### 4.5.1 Common pipeline

Sensor → strategy → payload:

| Sensor | `sensor.id` (= `SRSensor.rawValue`) | Strategy | Payload |
|---|---|---|---|
| visits | `com.apple.SensorKit.visits` | JSON | zstd JSON array of FHIR Observations |
| onWrist | `com.apple.SensorKit.onWristState` | JSON | 〃 |
| deviceUsage | `com.apple.SensorKit.deviceUsageReport` | JSON | 〃 |
| ecg | `com.apple.SensorKit.ECG` | JSON | 〃 |
| wristTemperature | `com.apple.SensorKit.wristTemperature` | CSV2 | zstd CSV **per session** |
| heartRate | `com.apple.SensorKit.heart.rate` | CSV1 | zstd CSV per batch |
| pedometer | `com.apple.SensorKit.pedometer.data` | CSV1 | 〃 |
| ambientLight | `com.apple.SensorKit.als` | CSV1 | 〃 |
| accelerometer | `com.apple.SensorKit.motion.accelerometer` | CSV1 | 〃 |
| ambientPressure | `com.apple.SensorKit.ambientPressure` | CSV1 | 〃 |
| ppg | `com.apple.SensorKit.PPG` | custom | **uncompressed** binary `.mhcPPG` |

Files: local name `{UUIDv4}.{csv|json}.zstd` / `{UUID}.mhcPPG` → Storage `users/{uid}/SensorKit/{sensor.id}/{filename}` (contentType always `application/octet-stream`).

**Firestore doc pair** per uploaded file, in `users/{uid}/HealthObservations_{sensor.id}/`:

1. `{docName}_Ref` — FHIR `DocumentReference`: `status: "current"`, one `content[].attachment` with `contentType: "application/zstd"` (⚠️ hardcoded — **also for uncompressed `.mhcPPG`**; trust the filename suffix instead), `creation`, `hash` (base64 SHA-1 of the **uploaded** bytes), `size` (omitted > 2 GiB), `url` **relative to the user's storage dir**: `SensorKit/{sensor.id}/{filename}`.
2. `{docName}` — FHIR `Observation`: `code.coding` = `{https://developer.apple.com/documentation/sensorkit, <sensor.id>, <displayName>}`, `derivedFrom` → the `_Ref` doc, `effectivePeriod` = actual sample span, extensions: nested sourceRevision (app as source), `SensorKit/sourceDevice` (model/name/systemName/systemVersion/productType — incl. paired-Watch info), sampleUploadTimeZone, study-enrollment.

docName: CSV1/JSON/PPG = `"{batchStart}_{batchEnd}"` (UTC ISO-8601 `Z`, the **queried window**, wider than the sample span); CSV2 = deterministic session UUID. ⚠️ `_Ref` is written before the Observation, and doc writes don't await the storage upload — readers may see pointers before (or without) payloads.

**Deterministic sample IDs**: `SensorKitSampleIDHasher` — 128-bit XOR/rolling-shift hash over the sample's identity fields, finalized into a version-4-shaped UUID. Stable across re-fetches (dedupe after anchor resets); not cryptographic.

#### 4.5.2 CSV strategy mechanics (CSV1 + CSV2)

UTF-8, no BOM; separator `,`; every row (incl. last) terminated `\n`; header row first; RFC-4180-style quoting only when a field contains `,`/`"`/newline (embedded quotes doubled). Dates → **epoch seconds, Swift Double description**. `nil` → empty field. CSV1 appends a `device` column to every row: `model=<m>; name=<n>; systemName=<s>; systemVersion=<v>; productType=<p>` — productType contains a comma (`Watch7,2`), so this field is routinely quoted; ⚠️ a naive `split(",")` breaks.

Headers (verbatim):

| Sensor | Header | Column notes |
|---|---|---|
| heartRate | `timestamp,value,confidence,device` | value = BPM Double; confidence = CoreMotion rawValue 0 low / 1 medium / 2 high / 3 highest |
| pedometer | `start,end,steps,distance,floorsUp,floorsDown,currentPace,currentCadence,avgActivePace,device` | distance m; ⚠️ pace values are CoreMotion **seconds-per-meter** (upstream comment claims m/s; passed through unconverted); cadence steps/s; optional fields empty when absent |
| ambientLight | `timestamp,lux,placement,chromacityX,chromacityY,device` | placement enum string (`frontTop`, `frontBottomLeft`, …); chromaticity Floats, 0 when unsupported |
| accelerometer | `timestamp,identifier,x,y,z,device` | x/y/z in G; identifier = UInt64 batch id |
| ambientPressure | `timestamp,identifier,pressure,temperature,device` | pressure kPa; temperature °C |
| wristTemperature (CSV2) | `timestamp,value,errorEstimate,condition` | one file per `SRWristTemperatureSession`; value/errorEstimate **°C**; condition = subset of `offWrist,onCharger,inMotion` comma-joined (quoted when multiple); **no device column**; extra Observation extension `…/SensorKit/WristTemp/algorithmVersion` |

#### 4.5.3 JSON strategy payloads (visits, onWrist, deviceUsage, ecg)

zstd → top-level JSON array of per-sample FHIR Observations (plain `JSONEncoder`). Common fields: `status: "final"`, `id` = deterministic UUID, `identifier: [{"id": "<uuid>"}]` (element id only), `code.coding[0]` = the sensor's SensorKit coding, one shared `issued` per file, per-sample extensions (sensorKitSourceDevice + timeZone + study-enrollment + sourceRevision).

- **visits**: `valueString` = location UUID (uppercase); `effectivePeriod` = arrival-range start → departure-range end (**maximal** span); extensions under `…/SensorKit/Visits/`: `sensorKitTimestamp` (valueDateTime), `locationId` (valueUuid, lowercase `urn:uuid:`), `distanceFromHome` (valueQuantity m), `arrivalRangeStart/End`, `departureRangeStart/End` (valueDateTime), `locationCategory` (valueString `home|work|school|gym|unknown`).
- **onWrist**: `valueBoolean` = on-wrist; `effective` absent / `effectiveInstant` / `effectivePeriod` depending on which of on/off-wrist dates exist; two components with system `https://spezi.stanford.edu`, codes `watchWristLocation` / `watchCrownOrientation`, valueString `left|right`.
- **deviceUsage**: `effectivePeriod` = timestamp → +duration; `valueQuantity` = totalUnlockDuration (s). Extensions under `…/SensorKit/DeviceUsage/`: `totalScreenWakes`, `totalUnlocks` (valueInteger), `totalUnlockDuration` (valueQuantity s), `version` (valueString); repeated nested `appUsage` (children: `category`, `bundleIdentifier` — ⚠️ may be **value-less** when Apple redacts third-party apps —, `relativeStartTime` valueDecimal s, `usageTime` valueQuantity s, `reportApplicationIdentifier`, repeated `textInputSession` {identifier, duration, type=SRTextInputSession rawValue}, repeated `supplementalCategory`); repeated `notificationUsage` {category, bundleIdentifier?, event=rawValue}; repeated `webUsage` {category, totalUsageTime}. Extension order nondeterministic (dictionary iteration).
- **ecg**: one Observation per logical session (requires `.begin` + `.active` state objects, else dropped); `code.coding` = SensorKit ecg + `{healthKit, HKElectrocardiogram}` + MDC 131328; `category` = procedure; one component **per voltage batch**, `valueSampledData` as §4.2.5 (µV, `%.3f`, `period` = 1000/Hz, `dimensions` 1). Lead/session-guidance dropped.

#### 4.5.4 PPG — `.mhcPPG` custom binary

**Not compressed. No magic bytes, no version field, no checksum.** The file is exactly the `BinaryCodable` encoding of `[PPGSample]`. Reference decoder: `MyHeartCountsShared/Sources/SensorKitCLI/DecodePPG.swift`; round-trip tests in `PPGBinaryCodingTests.swift`.

Primitive wire encodings (`MyHeartCountsShared/BinaryCodable/`):

| Type | Encoding |
|---|---|
| Int / Int64 / UInt64 / counts | **VarInt**: LEB128-style, low 7-bit group first, bit 7 = continuation, **no ZigZag**; negatives are 64-bit sign-extended → always 10 bytes |
| Double / Float | 8 B / 4 B IEEE-754; net wire order little-endian (host order; encoder double-swaps) |
| Bool / Optional flag | 1 byte `0x00`/`0x01` (anything else = decode error); Optional payload follows `0x01` |
| Date | Double epoch seconds |
| String | VarInt count of UTF-8 code units, then **each code unit individually VarInt-encoded** (ASCII 1 B; bytes ≥ 0x80 take 2 B) |
| Array / Set | VarInt count + back-to-back elements (Set order unspecified) |

File layout — `VarInt sampleCount`, then per `PPGSample` (⚠️ encode order ≠ struct order — temperature is 3rd):

| # | Field | Encoding |
|---|---|---|
| 1 | startDate | Double epoch s |
| 2 | nanosecondsSinceStart | VarInt Int64 |
| 3 | temperature (°C) | Optional\<Double\> |
| 4 | usage | VarInt count + Strings (SensorKit `Usage` rawValues) |
| 5 | opticalSamples | VarInt count + OpticalSample… |
| 6 | accelerometerSamples | VarInt count + AccelerometerSample… |

`OpticalSample`: emitter (VarInt) · activePhotodiodeIndexes (Set\<Int\>: VarInt count + VarInt each, unordered) · signalIdentifier (VarInt) · nominalWavelength nm (Double) · effectiveWavelength nm (Double) · samplingFrequency Hz (Double) · nanosecondsSinceStart (VarInt) · conditions (Strings) · noiseTerms (Optional: whiteNoise, pinkNoise, backgroundNoise, backgroundNoiseOffset — 4 Doubles) · normalizedReflectance (Optional\<Double\>).

`AccelerometerSample`: nanosecondsSinceStart (VarInt) · samplingFrequency Hz (Double) · x, y, z in G (Doubles).

Units are normalized at conversion (wavelengths → nm, frequencies → Hz, acceleration → G, temperature → °C). Observation `effectivePeriod` = first→**last sample startDate** (samples ~ordered; ≤10 ms inversions observed).

### 4.6 Other artifacts

#### 4.6.1 Consent PDF

Storage `users/{uid}/consent/{Int(unixSeconds)}.pdf`, contentType `application/pdf`, body = raw PDF. customMetadata (all strings): `consentFormMetadata` = JSON of the markdown frontmatter (flat string→string map, e.g. `{"title":…,"version":"1.0.0"}`); `responses` = JSON `{"toggles":{id:bool},"selects":{id:optionId},"signatures":{id:{name:{givenName,familyName},signature:<opaque PencilKit blob, base64>,size:[w,h]}}}`; `date` = ISO-8601 UTC `Z`; `version` = semver (only if frontmatter had one).

#### 4.6.2 Study bundle — `public/mhcStudyBundle.spezistudybundle.aar`

An **Apple Archive** (LZFSE `compressionStream`; header fields `TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM`) of a `.spezistudybundle` directory: `definition.json` (`StudyDefinition`, schema owned by SpeziStudyDefinition) + per-category folders `consent/`, `questionnaire/`, `article/` (+`assets/`), `hhdExplainer/`, with localized resources named `{name}+{lang}-{REGION}.{ext}` (the `+localization` infix is mandatory). Fetched by the app via the public Storage REST URL.

#### 4.6.3 `users/{uid}` account document

Plain Firestore fields written by FirestoreAccountStorage (`setData(merge: true)`; removed keys via `FieldValue.delete()`). Field name = `@AccountKey` id. Representative encodings:

| Field(s) | Encoding |
|---|---|
| `dateOfEnrollment`, `lastSignedConsentDate`, `lastActiveDate`, `dateOfBirth` | Firestore Timestamp |
| `preferredWorkoutTypes` | single comma-joined string (`"run,swim,HIIT"`) |
| `preferredNotificationTime` | string `"HH:mm"` |
| `raceEthnicity` | integer **bitmask** (OptionSet rawValue) |
| `comorbidities` | map `{comorbidityId: "" \| "yyyy" \| "yyyy-MM"}` |
| `mhcGenderIdentity`, `bloodType` | integer rawValues |
| `usRegion` | state abbreviation string |
| income/education/latinoStatus/stageOfChange/referralSource/mostRecentOnboardingStep | enum rawValues (string or int) |
| `heightInCM`, `weightInKG` | Double |
| booleans (`hasWithdrawnFromStudy`, `didOptInToTrial`, …) / strings (`fcmToken`, `timeZone`, `language`, …) | as-is |

⚠️ Decoder gotcha: any field whose key isn't in the app's configured `AccountConfiguration` is **silently dropped on decode** even though it persists in Firestore.

#### 4.6.4 Notification tracking & feedback

- `users/{uid}/notificationTracking/{UUID}`: `{timestamp: Timestamp, timeZone, event: "opened", notificationId (= backlog doc id), additionalStuff: String(describing: userInfo) — a Swift dict dump, not JSON}`.
- `feedback/{UUID}` (root): `{version: 1, accountId, message, date: Timestamp, timeZone, appVersion, appBuildNumber (−1 if unknown), deviceInfo: {osVersion, model, type}}`.

#### 4.6.5 Nudge documents (server-written)

- `users/{uid}/notificationBacklog/{UUID-uppercase}`: `{id (= doc id), title, body, timestamp (Timestamp, scheduled send), category: "nudge-predefined"|"nudge-llm"|"nudge-posttrial"|"nudge-posttrial-welcome", isLLMGenerated, generatedAt, llmPrompt?, llmPromptVersion?, llmTokenUsage?{promptTokens,completionTokens,totalTokens}, llmModel?}`.
- `users/{uid}/notificationHistory/{same id}`: backlog fields minus `timestamp`, plus `originalTimestamp`, `processedTimestamp` (serverTimestamp), `status: "sent"|"failed"`, `errorMessage?`. Backlog doc deleted after processing. FCM push carries `data.notificationId` = doc id (ties to §4.6.4).

### 4.7 Cross-cutting decoder gotchas (consolidated)

1. Clinical records are the only **wrapped** FHIR payloads (`{"version":…,"resource":…}`) and coexist with bare Observations in `liveHealthSamples` files.
2. `issued` = conversion/ingestion time, not upload time — staged uploads lag ≥3 days.
3. Two HealthKit coding "systems" (http type codings vs https value codings with collapsed nested type names); enum value codes are decimal rawValue strings.
4. Percent quantities are ×100 on the wire (0…100).
5. Historical files lack MHC extensions and ECG voltages; live files have everything.
6. UUID casing fingerprints the writer (uppercase iOS / lowercase functions).
7. Nondeterministic orders: JSON keys everywhere; BP-correlation components; ECG symptom components; deviceUsage extension groups; PPG photodiode sets. Match by code/URL, never by index.
8. Three time encodings (FHIR local-offset strings, CSV epoch Doubles, UTC-`Z` docNames/filenames).
9. CSV fields with commas (`device`, wristTemp `condition`) are quoted — use a real CSV parser.
10. SensorKit `_Ref` attachment `contentType` is hardcoded `application/zstd` even for uncompressed `.mhcPPG`; Storage contentType is always `application/octet-stream` — the filename is the truth.
11. Firestore doc pairs can momentarily exist without their storage payload (and vice versa).
12. The two-dialect problem in shared observation collections (§4.3.5).
13. GAD-7 HK samples never reach the pipeline (§4.2.7).

---

## 5. The Statistics Layer

> **STATUS: DESIGN PROPOSAL — NOT IMPLEMENTED.** Nothing in this section exists in code. There is no `healthStats` collection; today the dashboard computes everything from local HealthKit queries plus four per-observation Firestore listeners (§2.1, §3.2). The design is under active iteration (schema last restructured 2026-08-06) and gated on the §7 open questions. It is written in normative present tense ("contributors write…") as spec convention for the *target* system — do not read any of it as a description of current behavior.

The proposed client query tier: per-metric Firestore documents of precomputed *inputs*, with per-source subtrees, intended to become the primary read path for all client health-data UI. Design decisions from the 2026-08 review (directional agreements, none implemented):

| # | Decision |
|---|---|
| D1 | Stats docs are the **primary client read path** for health data (doc-primary reads); raw samples live in files (§3), event-like data in Firestore observation docs. |
| D2 | **Device-computed contributions for device sources** (iOS from HealthKit, Android from Health Connect); the server computes only API-based sources, folding from files. |
| D3 | Precompute **inputs, never scores** — banding/composites stay on-device (§5.6.5). |
| D4 | **No non-recomputable state** in any document (no lifetime counters, no LUB extrema); long-horizon values are folds over month documents. |
| D5 | Manual entries live in `HealthObservations_*` (§4.3.1), not in stats docs; they join the merge as source `manual`. Manual entry drops its HealthKit write (OQ-6). |
| D6 | Questionnaire responses, walk-test results, and server scores keep their existing Firestore paths. |
| D7 | Per-sample fan-outs (frozen Storage→Firestore; wearable branch's `<Provider>Observations_*`) are superseded, not revived. |

Goals: render the union of all sources; bounded cheap reads; multi-writer safety by construction; reinstall/device-switch/cross-platform continuity; one versioned, testable contract for Swift/Kotlin/TypeScript. Non-goals: not a research surface (OQ-1); no raw-sample replication; no server-computed scores; no sub-day granularity (§5.3).

### 5.1 Terminology & IDs

**Documents are partitioned by sample type (metric)**: one document family per metric, shared by all sources. **Source** = one contributor identity, appearing as a namespaced subtree *inside* each document. **Contributor** = the process writing a source's subtrees. **Reader** = client code producing the merged view. **Day key** = `YYYY-MM-DD` calendar-day *label* in the subtree's declared tz (labels, not instants — DST-safe). **Latest register** = per-source most-recent observation record for the metric. **Merge** = §5.6.

`metricId` matches `^[a-z][a-zA-Z0-9]*$` (camelCase, **no `_`**, so `{metricId}_{YYYY-MM}` splits unambiguously); `index` and `merged` are reserved doc names. `sourceId` (subtree keys) matches `^[a-z][a-z0-9-]*$`; the **`srv-`** prefix is reserved for server-authored sources (rules-enforced, §5.7).

| sourceId (subtree key) | Written by |
|---|---|
| `ios` / `android` | device apps (device-computed) |
| `srv-withings`, `srv-fitbit`, `srv-oura` | Cloud Functions (from files) — future |
| `srv-ios-backfill` | *reserved*: a server job recomputing from the GCS archive must never write the `ios` subtrees |
| `merged` | *reserved* as a doc name: server-owned pre-merged view, not in v1 |

The manual-entry source has no `healthStats` subtrees (D5); it joins at merge time as `manual`.

### 5.2 Document model

```
users/{uid}/healthStats/index                   # one doc: per-source metadata
users/{uid}/healthStats/{metricId}              # head doc: per-source latest registers
users/{uid}/healthStats/{metricId}_{YYYY-MM}    # month doc: per-source day cells / series / sessions
```

**The cardinal structural rule**: inside every document, each source owns exactly the subtree `sources.{sourceId}` and writes it **only** via field-path-scoped writes — canonical primitive: `set(data, mergeFields: [FieldPath(["sources", "<id>"]), "v", "kind", "metric", "month"])`, which upserts the doc and **replaces** exactly the listed paths (handles the doc-not-yet-existing case that plain `update` fails on with NOT_FOUND). Never whole-doc `set`, and **never `merge: true`** — recursive map-merging would resurrect days a recompute legitimately dropped, violating the full-recompute contract. Two writers touching disjoint subtrees of one document cannot clobber each other, and an offline client replaying a stale write harms only its own subtree (healed by its next recompute). Security rules see the post-write image for every write mode, so the §5.7 `Map.diff` rule enforces the subtree boundary regardless of which API produced the write. **No pre-merged cross-source values are ever stored** (v1); merging happens at read time (§5.6).

**Index document** (`healthStats/index`) — per-source metadata, one entry per source:

```jsonc
{
  "v": "1.0", "kind": "index",
  "sources": {
    "ios": {
      "schemaVersion": "1.0",          // "<major>.<minor>" (§5.8)
      "sourceKind": "device",          // "device" | "server"
      "status": "active",              // "active" | "disabled" (§6.3)
      "tz": "America/Los_Angeles",
      "updatedAt": <serverTimestamp>,  // authoritative freshness signal
      "computedAtLocal": "2026-08-06T09:14:02-07:00",
      "platform": { "os": "iOS 26.5", "app": "2.4.0 (431)" },   // optional; PHI-minimal (OQ-1)
      "coverage": { "firstDay": "2025-08-01", "lastDay": "2026-08-06" }
    },
    "srv-withings": { "schemaVersion": "1.0", "sourceKind": "server", "status": "active",
                      "tz": "America/Los_Angeles", "updatedAt": <serverTimestamp>,
                      "coverage": { "firstDay": "2026-03-01", "lastDay": "2026-08-06" } }
  }
}
```

**Head document** (`healthStats/bloodPressure`) — the metric's latest register, per source:

```jsonc
{
  "v": "1.0", "kind": "latest", "metric": "bloodPressure",
  "sources": {
    "ios":          { "latest": { "sys": 122, "dia": 79, "unit": "mmHg",
                                  "start": "2026-08-01T08:10:00-07:00", "end": "2026-08-01T08:10:00-07:00" },
                      "updatedAt": <serverTimestamp> },
    "srv-withings": { "latest": { "sys": 118, "dia": 76, "unit": "mmHg",
                                  "start": "2026-08-06T07:04:00-07:00", "end": "2026-08-06T07:04:00-07:00" },
                      "updatedAt": <serverTimestamp> }
  }
}
```

Scalar metrics use `{ "val": …, "unit": …, "start": …, "end": … }`; sleep's register is `{ "asleepSec": …, "start": …, "end": …, "method": "hk-apple-60min" }`.

**Month document** (`healthStats/steps_2026-08`) — day cells per source; because the document is already metric-scoped, a day entry *is* the metric's cell:

```jsonc
{
  "v": "1.0", "kind": "month", "metric": "steps", "month": "2026-08",
  "sources": {
    "ios": {
      "tz": "America/Los_Angeles", "updatedAt": <serverTimestamp>,
      "days": {
        "2026-08-05": { "sum": 8123 },
        "2026-08-06": { "sum": 3021, "complete": false }   // current partial day
      }
    },
    "srv-fitbit": { "tz": "America/Los_Angeles", "updatedAt": <serverTimestamp>,
                    "days": { "2026-08-05": { "sum": 11020 } } }
  }
}
```

Series metrics carry `sources.{id}.series: [ { "t": …, "sys": 118, "dia": 76 } ]` (or `{t, val}`) instead of `days`; sleep months carry `days` whose cells are `{ "asleepSec", "nSessions", "sessions": [ {start, end, asleepSec} ] }`; workout cells `{ "n", "durationSec", "longest": {durationSec, type, end} }`.

**Why the month split stays** (vs one literally-single doc per metric): a single ever-growing doc trends toward the 1 MiB limit (BP series over years), re-sends its whole growing self to every listener on every write, and rewrites unboundedly much state per sync. Month docs are bounded, immutable-once-closed in practice, and cache-friendly. The head doc keeps tiles single-read; months serve charts/windows.

**Conventions**: all instants ISO-8601 with explicit offset (byte-stable golden vectors across three languages); `updatedAt` (per source subtree + index) are the only serverTimestamps — merges never order by wall clocks; day keys are calendar-day labels in the subtree's `tz` (DST days are 23/25 h and bucket correctly; on tz change the contributor recomputes its trailing window, historical keys keep their boundaries); sessions belong to the day of their **end**; day-cell **absence means "no data"** (never write zeros for unmeasured days); canonical units fixed per metric by §5.4 — contributors convert at the edge, apply the clamps, and drop-and-report out-of-range values.

**Size budgets**: index + head docs ≤ 8 KB; month ≤ 150 KB soft (alert at 100 KB) — a 4-source steps month is ~10 KB, comfortably bounded. `series` caps **per source** per month: bloodPressure 250, others 150 (keep newest, list overflowed metrics in the subtree's `seriesTruncated: ["bloodPressure"]`); sleep sessions ≤ 8/day (keep longest).

**Indexing**: `fieldOverrides` exemptions disabling auto-indexing of `sources` for the `healthStats` collection group; only `kind`, `metric`, and `month` need indexes.

### 5.3 Metric kinds & the grain ceiling

| Kind | Day-cell shape | Examples |
|---|---|---|
| `cumulative` | `{sum}` | steps, exerciseMin, activeKcal, distanceWalkRun |
| `discrete` | `{avg,min,max,n}` | heartRate, restingHeartRate |
| `session` | `{asleepSec,nSessions,sessions[]}` | sleep |
| `event` | `{n,durationSec,longest{}}` | workouts |
| `latest` | summary register entry | bodyMass, height, bmi, bloodPressure, bloodGlucose, sleepSession |
| `series` | month `series` array | bloodPressure, bodyMass, bloodGlucose |

**Grain ceiling**: day grain + sessions + low-volume series covers every currently reachable UI shape. Sub-day granularity (15-min HR buckets) is out of scope; if needed later, add an `hourly` map as an additive extension (§5.8) or serve from files. Never widen `days` cells.

### 5.4 Metric registry (v1)

Adding a metric = spec PR + contributor emission, never a migration. Tier `core` = dashboard v1; `ext` = achievements/participation stats.

| metricId | Kinds | Unit | Clamp | Merge policy (§5.6.3) | Display window (§5.6.4) | Tier |
|---|---|---|---|---|---|---|
| `steps` | cumulative | count | 0…200 000/day | per-day **max** across sources | 7 days ending yesterday (mean of daily sums); charts | core |
| `exerciseMin` | cumulative | min | 0…1 440/day | per-day max | 7 days ending yesterday (sum) | core |
| `activeKcal` | cumulative | kcal | 0…20 000/day | per-day max | charts | ext |
| `distanceWalkRun` | cumulative | m | 0…400 000/day | per-day max | charts | ext |
| `flights` | cumulative | count | 0…5 000/day | per-day max | — | ext |
| `heartRate` | discrete | bpm | 20…250 | priority source per day | — | ext |
| `restingHeartRate` | discrete | bpm | 20…150 | priority source per day | — | ext |
| `sleep` | session (+ register) | s | session ≤ 24 h | **OQ-2**; interim: device sources only, >50 %-overlap dedupe | most recent session ≤ 14 d | core |
| `workouts` | event | s | ≤ 24 h | union by (end ± 5 min, type) | — | ext |
| `bodyMass` | latest + series | kg | 25…450 | argmax `end` | 6 months (BMI staleness rule) | core |
| `height` | latest | m | 0.9…2.5 | argmax `end` | 5 years | core |
| `bmi` | latest + series | kg/m2 | 8…100 | argmax `end` | comparative recency (existing decision tree) | core |
| `bloodPressure` | latest + series | mmHg | sys 60…250, dia 30…150 | argmax `end`; **atomic sys/dia pair** | 3 months | core |
| `bloodGlucose` | latest + series | mg/dL | 40…400 | argmax `end` | 14 days | core |
| `sleepSession` | latest register | s | ≤ 24 h | argmax `end` (OQ-2 source policy) | 14 days | core |

Clamps mirror the manual-entry validation ranges (§2.2) and must catch the §2.8 provider traps. **Not in the registry** (existing read paths): diet MEPA, WHO-5, nicotine, LDL, walk-test results, manual observations — consumers filter `entered-in-error`.

### 5.5 Contributor protocol

**Cardinal rules (all contributors)**:
1. **Exclusive ownership** — write only your own `sources.{sourceId}` subtrees (plus your `index.sources.{sourceId}` entry), exclusively via field-path-targeted updates. Never whole-doc `set` on any healthStats document.
2. **No deltas, ever** — no `FieldValue.increment`, no read-modify-append. Every write is a **full recompute of the affected subtree content from the authoritative store**: a pure function of current state, idempotent by construction (crashes, retries, offline replays self-heal on the next recompute).
3. **Write discipline** — one sync = one `WriteBatch` covering the index entry + every touched metric head/month doc (atomic, ≤500 ops); replace your subtree (or targeted day paths within it) wholesale per recompute; **never write an empty subtree over a non-empty one** (fresh-device guard); version-fence (a doc whose other subtrees carry a newer *major* `schemaVersion` → still write only your own subtree, additively, and surface update-required; never touch what you don't understand); **hash-diff** (skip byte-identical writes — they'd still bump `updatedAt` and thrash caches).
4. **Clamps** (§5.4): drop out-of-range values and count them (§5.10).
5. Emit `coverage` honestly (index entry).

**iOS contributor** (device-computed): store = local HealthKit. Triggers: HK observer callbacks while foregrounded, debounced 30–120 s (doc-primary reads make UI-cadence writes mandatory); scene-phase active; ~6 h BG task; explicit refresh. Dirty-day set = days of delivered samples (covers late Watch syncs and retro-inserts) ∪ trailing 7 days ∪ **trailing 60 days for a type on any deletion event** (HKDeletedObject has no dates, §2.1) ∪ trailing 45 days on tz change (recomputed in the new tz). Weekly sweep: recompute trailing 12 months, write hash-diffs only. Backfill: 12 months, one month per task execution, fleet-jittered (§5.9). Respect the collection gate; on unenroll/logout set `index.sources.ios.status: "disabled"`, never delete.

**Android contributor** (future): identical against Health Connect; changes-token diffs = dirty signal; ~30-day retention bounds the live window.

**Server contributors** (API sources): pull/webhook → raw payloads to file storage (§2.8) → recompute affected (day, metric) → write `srv-{provider}` docs; prefer provider daily-summary endpoints (already aggregates); re-running any ingest is a no-op. `tz` = provider profile tz, else the user doc's `timeZone`. Disconnect → §6.3.

### 5.6 Reader protocol (doc-primary)

**Fetch**: snapshot listeners on `index` + the head docs of displayed metrics (~8 core metrics) + the **current month docs** of windowed metrics (steps, exerciseMin, sleep; + previous month near boundaries); older months via **cache-first one-shot `get()`s** as chart ranges demand. Never listen to the whole collection (initial snapshot = all history). Read cost is bounded by *metric count*, independent of how many sources the user has — and a consumer that needs only one metric (e.g. a future widget, or a server job reading steps) fetches exactly that metric's docs. Firestore persistence + pending-write listener events make device-source updates render in ~seconds. Implement as **one shared stats module**, not per-view property wrappers — do not reproduce `MHCFirestoreQuery`'s listener-installed-once bug, and note two `@CVHScore` instances exist simultaneously today.

**Merge inputs**: (1) non-disabled `healthStats` sources with compatible major version; (2) the `manual` source from `HealthObservations_*` (filtered `entered-in-error`); (3) the questionnaire-score collections (unchanged); (4) **migration fallback** — where a window predates a device source's `coverage.firstDay`, local HealthKit/Health Connect backstops the gap (retired per-user once coverage suffices).

**Merge algorithm** (normative, golden-vectored §5.11; pure function `merge(docs, now, tz, priorityTable)`):
1. Drop disabled sources and subtrees whose index entry carries a newer major `schemaVersion`.
2. Cumulative: per (day, metric) = **max across sources** — never sum (the same activity commonly reaches two stores; max is duplication-idempotent; bounded undercount for genuinely disjoint capture is accepted and documented).
3. Discrete: highest-priority source per day. Priority v1: `manual > local platform > srv-fitbit > srv-withings > srv-oura`.
4. Latest registers: argmax `end`; **near-dup suppression** (±5 min, equal value ±1 quantum = one physical reading; keep highest-priority copy); BP stays an atomic pair.
5. Series: union, deduped by (minute-rounded t, values).
6. Sleep: OQ-2 interim — device sources only; >50 % time-overlap dedupe; most-recent-night = argmax session `end`.

**Staleness & windows**: staleness is **per-metric, on sample `end`, against the §5.4 display windows** — never per-doc on `updatedAt` (a quiet-but-valid scale must not gray out a still-valid weight); `updatedAt` feeds monitoring/UI freshness only. Ignore entries with `end > now + 24 h`. Windows ("7 days ending yesterday", chart ranges) are evaluated over merged day-key labels in the reader's calendar; ±1-day traveler skew at the edges is accepted.

**Scoring stays on-device** (D3): band tables, CVH composite (mean of ≥5 clamped components), exercise-vs-steps preference, WHO-5 ×4 display scaling + composite exclusion, ethnicity-dependent BMI banding — all client code over merged inputs. Nothing in this layer stores a score.

### 5.7 Security rules

Shared documents mean the doc-ID prefix trick no longer works; the server-source protection moves to **field granularity via `Map.diff()`**. The generic wildcard must exclude `healthStats` (rules OR together; a specific block can only grant), and the healthStats block permits a client write only when the set of *changed* `sources` keys is client-owned:

```diff
 match /users/{userId}/{collectionName}/{documentId} {
   allow read: if isUser(userId);
-  allow write: if isUser(userId);
+  allow write: if isUser(userId) && collectionName != 'healthStats';
 }
+match /users/{userId}/healthStats/{docId} {
+  allow read: if isUser(userId);
+  allow write: if isUser(userId)
+    && docId != 'merged'
+    && request.resource.data.get('sources', {})
+         .diff(resource == null ? {} : resource.data.get('sources', {}))
+         .affectedKeys()
+         .hasOnly(['ios', 'android']);
+}
```

Server contributors use the Admin SDK (bypasses rules) and may touch `srv-*` subtrees and `merged`. Notes: `affectedKeys()` covers adds, removals, and modifications, so a client can neither forge nor delete a `srv-withings` subtree; top-level constants (`v`, `kind`, `metric`, `month`) remain client-writable — self-describing garbage is self-harm only, same trust class as today. `ios`/`android` subtrees and manual observations stay user-forgeable — unchanged from every existing health collection; consequences: nothing client-sourced feeds research or cross-user aggregates without server-side provenance filtering (OQ-1); App Check is the umbrella hardening item, out of scope. Deeper content validation isn't practically expressible in rules — contributors self-validate, the server monitors. Required rules tests: client write touching `sources.srv-withings` denied (modify **and** delete); write to `merged` denied; own-subtree writes allowed; whole-doc `set` replacing a `srv-*` subtree with identical content allowed by rules but forbidden by protocol (§5.5) — covered by contributor tests instead; reads allowed.

### 5.8 Schema evolution

Two version fields: doc-level `v` (structure of this document kind) and per-source `schemaVersion` in the index (the contributor's spec level; governs how its subtrees are read). Within a major: **additive only** — readers ignore unknown keys and unknown metric docs, writers never touch subtrees or fields they don't understand. Adding a metric = a new doc family, inherently additive. Breaking change = **new doc-ID family** (`stepsV2`, `stepsV2_{YYYY-MM}`) with a dual-write window ≥ one release cycle — never "newer version → clients back off" as a rollout mechanism (a server-side bump would blank tiles fleet-wide). Writers seeing newer-major sibling subtrees keep writing their own subtree additively and surface update-required. Registry, priority table, and merge rules are versioned with this spec; semantic changes need study-team sign-off (OQ-3).

### 5.9 Rollout & migration

**Kill switch is mandatory** (doc-primary reads: an empty/stale doc is a blank dashboard; `FeatureFlags` is launch-args-only): root config doc, e.g. `config/clientFeatures { healthStatsWriter, healthStatsReader }` — server-only write, authenticated read; default off.

Phases: ① rules diff + index exemptions + config doc (inert) → ② iOS contributor **write-only (shadow mode)** + jittered 12-month backfill; monitor sizes/rates → ③ reader behind the flag with the local-store fallback; flip when coverage verified → ④ server contributors (with wearable integrations) → ⑤ Android → ⑥ optional consolidation (scoring services dual-write a `srv-scores` register; retire the four full-collection custom-type listeners after a release cycle). Old app versions never touch `healthStats`; they present as a stale `ios` source (visible via `updatedAt`).

### 5.10 Monitoring

Before the second contributor ships: ① staleness audit (scheduled function over `index` docs: `active` but `updatedAt` older than per-sourceKind horizon — device 7 d, server 2× poll cadence); ② garbage audit (clamp-drop counters, alert on spikes); ③ size audit (month docs > 100 KB); ④ Firestore budget alerts in all three projects (dev, prod-US, prod-UK); ⑤ client "last updated" affordance per source (the freshness-asymmetry answer: local ≈ seconds, providers ≈ hours).

### 5.11 Golden test vectors

The cross-language drift guard (aggregation + merge in Swift, Kotlin, TS per D2 — the in-repo nicotine enum duplication is the cautionary precedent). One canonical fixture set run by XCTest, JUnit, mocha. Home: OQ-3 (default MyHeartCounts-StudyDefinitions).

Format — one JSON per case: `{name, spec, now, readerTz, sources: {docId: fullDocJSON}, expected: {mergedDays, mergedLatest, windows}}`.

Required case classes: duplicated source (idempotence); commutativity; per-day max-vs-sum trap; near-dup latest suppression (Withings via HealthKit *and* server); BP atomic pairing; per-metric staleness (quiet-scale: 3-week-old weight survives); DST spring/fall; month-boundary 7-day window; partial current day; empty source; unknown metric key preserved; newer-major doc skipped; coverage-gap fallback boundary; clamp rejection. Contributor-side (per platform): recompute idempotence (twice ⇒ byte-identical), never-empty-over-non-empty, version fence, deletion 60-day window. iOS UI tests: emulator-seeded fixtures with **run-date-relative day keys** (absolute keys decay at midnight); suppress the stats writer during `--setupTestEnvironment` reset; emulator uses memory cache → offline-persistence behavior needs a manual device protocol; mind the dev vs UI-test project-ID namespace split.

### 5.12 What the statistics layer does not change

CVH scoring/banding/composite (client code); questionnaire responses, scoring services, walk-test results (existing paths, D6); the raw upload pipeline (§3 — files remain the research record; stats never depend on upload latency); the achievements unlock ledger (`achievementTracking`, LUB-merged — its *metric inputs* switch to folds over merged month docs, D4).

---

## 6. Data Lifecycle: Deletion, Withdrawal, Retention

### 6.1 Account deletion — ACTIVE

The existing sweep recursively deletes Firestore `users/{uid}` (questionnaireResponses, all `HealthObservations_*`, and — once it exists — `healthStats`), deletes the Storage prefix `users/{uid}/` (all file tiers), and removes the Auth user. Nothing in this spec, current or proposed, needs additional handling — stated so the invariant is explicit.

### 6.2 Sample deletion

- **Device stores**: today, deletions do not propagate beyond the unconsumed tombstone CSVs (§4.4.3, OQ-7) — already-uploaded data is never retro-deleted. Under the §5 proposal this becomes structural: deletions change the store, and the stats contributor's dirty-window recompute rewrites the truth (§5.5); no tombstone protocol in the stats layer.
- **Firestore observation docs**: the existing `deleteHealthSamples` entered-in-error flow (whitelist matches `HealthObservations_*`); every consumer filters the status.
- A deletion service touching provider data must enqueue an `srv-*` stats recompute for the affected days.

### 6.3 Withdrawal, logout & provider disconnect

Today: raw collection stops via the existing gate (§2.1); nothing else happens. Under the §5 proposal, the contributor additionally sets its `index.sources.{sourceId}.status: "disabled"` (one small write) and stops; readers ignore disabled sources; re-enrollment flips back and resumes; provider disconnect uses the same `disabled` mechanism for `srv-{provider}` (no delete — history stays auditable; revisit under OQ-1/OQ-5).

### 6.4 Retention

Files and Firestore observation documents: indefinite today (research record, protocol-governed). Stats month documents: indefinite pending OQ-5; the reader's fan-out is bounded to 12 months regardless.

---

## 7. Open Questions

| # | Question | Owner | Interim rule |
|---|---|---|---|
| OQ-1 | Is `healthStats` a research-readable surface or app-only convenience? Drives provenance hardening, retention, BigQuery export, consent/IRB review, and whether `platform` metadata should be dropped. | study team + Lukas | App-only; nothing client-sourced leaves the user's own UI. |
| OQ-2 | Non-Apple sleep in the CVH sleep score (current behavior is deliberately Apple-source-only). | study team | Device sources only, overlap-deduped; provider sleep excluded from score and register. |
| OQ-3 | Canonical home + change-approval process for this spec, the metric registry, and golden vectors; Android timeline. | Lukas | Spec lives in this repo; proposed home: MyHeartCounts-StudyDefinitions. |
| OQ-4 | May server-side consumers (nudge planner) read `healthStats`? RCT-integrity question. | study team | No server consumer reads client-source docs. |
| OQ-5 | Retention/TTL for stats month docs. | study team | Indefinite; reader fan-out bounded to 12 months. |
| OQ-6 | Manual entries (and heartRisk's on-device BP/glucose extraction, §2.3) stop writing into HealthKit entirely vs dual-write when access is granted. | Lukas / product | No HK write; `HealthObservations_*` is the sole record. |
| OQ-7 | Fate of the frozen GCS `liveHealthSamples` backlog and the never-consumed `healthDeletions` tombstones. | Lukas + research team | Untouched; `srv-ios-backfill` reserved if ever folded into stats. |
| OQ-8 | GAD-7 HealthKit samples are silently dropped (no FHIR mapping, §4.2.7) — add a mapping upstream, or accept questionnaire-only GAD-7? | Lukas | Questionnaire-only; documented gap. |

---

*Drafted 2026-08-06 with Claude (design review: 6-agent recon + 3 competing designs + adversarial/completeness critiques; format reference: 4 extraction agents over app + Spezi package sources + backend, spot-verified by hand; all archived). Not yet reviewed by the study team.*
