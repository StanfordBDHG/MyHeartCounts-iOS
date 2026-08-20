<!--
This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project

SPDX-FileCopyrightText: 2026 Stanford University

SPDX-License-Identifier: MIT
-->

# MHC Data - Sources, Storage & Formats (DRAFT; iOS pov)


## High-level data persistence locations
- The app uses a firebase backend to store server-persisted data
  - Within that, it uses both firestore as well as firebase storage
- This document mainly covers the iOS app's data flow/structure, but does also go a bit into server-relevant things
- Data that does not need to persist across multiple installs of the app is stored as `UserDefaults`


## What data does the app produce/collect?
- demographics
- user / account flags/settings/preferences
- consent pdf
- device environment data (time zone, heartbeat, etc)
- automated data donation (healthkit, sensorkit)
- user-provided data entered into the app (questionnaires, active tasks, custom quantity samples, etc)
- scheduler state (*todo*)
- (outside of iOS app) data coming from third-party wearable devices


### Demographics Data
- Demographics data is collected from the user as part of the onboarding
- The list of questions collected in the demographics (and their conditions) is defined in the google sheet
- Responses to the demographcis fields are stored in the user document in firebase (see DemographicsAccountKeys.swift)


### User/Account Flags/Preferences
- Stored in the user document (`/users/{uid}`) in firestore

#### User-Visible Account Keys
| Account Key | Type | Description |
| :---------- | :--: | :---------- |
| `hasWithdrawnFromStudy` | `Bool` | Tracks whether the user has explicitly requested to withdraw from the study, via the in-app button in the account sheet. If the value is `false` or absent, the user has not withdrawn. Not written directly by the app; managed by the `markAccountForStudyWithdrawal` and `markAccountForStudyReenrollment` functions |
| `dateOfEnrollment` | `Date` | Timestamp of when the user first enrolled into the study |
| `lastSignedConsentVersion` | `String` | SemVer version string of the user's last-signed consent document version |
| `lastSignedConsentDate` | `Date` | Timestamp of when the user last signed the consent document |
| `didOptInToTrial` | `Bool` | Tracks whether the user opted in to the trial during onboarding |
| `preferredWorkoutTypes` | `String` | Comma-separated list of workout preference identifiers (e.g. `"walk,bicycle"`) |
| `preferredNotificationTime` | `String` | The user's preferred time to receive nudge notifications. Format: `"HH:mm"` |
| `extendedActivityNudgesOptIn` | `Bool` | Whether the user decided to opt in to receive post-trial nudged. Missing value means the user is opted in. |

#### Internal Account Keys
| Account Key | Type | Description |
| :---------- | :--: | :---------- |
| `lastActiveDate` | `Date` | Timestamp when the user last opened the app. Does not get updated when the app is launched in the background |
| `fcmToken` | `String` | The app's FCM token |
| `enableAppDebugMode` | `Bool` | Whether the app's debug mode should be enabled for the user |
| `timeZone` | `String` | Last-seen device time zone |
| `language` | `String` | Last-seen device/app language |
| `preferredMeasurementSystem` | `String` | Last-seen preferred measurement system (e.g., `metric`, `ussystem`, or `uksystem`) |
| `mostRecentOnboardingStep` | `String` | Identifier of the most recent onboarding step reached by the user |



### Active Tasks
- MHC currently has the following kinds of active tasks:
  - Questionnaires we prompt the user to fill out and answer
  - Timed Walk/Run Test results
  - ECGs
- These data are collected as FHIR resources:
  - [QuestionnaireResponse][R4QuestionnaireResponse] for the questionnaires
  - [Observation][R4Observation] for the timed walk/run tests and the ECGs
- For questionnaires: in addition to creating a FHIR resource representing the questionnaire response as a whole, the app also extracts supported quantity values from questionnaire responses and writes them to HealthKit, triggering the regular HealthKit ingestion pipeline (see below)
  - This is currently the case for the "Heart Risk" questionnaire, which contains questions collecting values for blood pressure and blood glucose
  - The system is extensible and should be updated to cover additional questionnaires as well, where possible


### Custom Quantity Samples
- MHC supports data entry (via the dashboard) for quantity sample types not supported by HealthKit
  - (It also supports data entry for HealthKit-supported quantity sample types; in these cases the entered data simply gets saved into HealthKit and ptocessed via the pipeline described below)
- Custom quantity values (i.e., blood lipids / LDL cholesterol, and A1c blood glusose) are encoded as FHIR [Observation][R4Observation]s and 


### HealthKit

- MHC collects HealthKit data
- The set of `HKSampleType`s we collect is defined in the study definition
- During the onboarding, the user is asked to grant us access, and the app registers automatic background observers for all sample types listed in the study definition
- iOS will periodically wake the app in the background to inform it of new samples that were added to the Health database
  - The app then ingests these samples using the processing pipeline outlined below
- HealthKit data is represented as FHIR [Observation][R4Observation]s (except `HKClinicalRecord` values; see below)
- MHC perfoms two kinds of data ingestion from HealthKit:
  1. Collection of live Health data (i.e., `HKSample`s added to HealthKit after the user's enrollment in the study)
  2. Collection of historical Health data (i.e., `HKSample`s that already exist in HealthKit at the time of the user's enrollment)
- Live health data collection is handled via the above-mentioned background observer queries
- Historical health data collection is handled by the `HistoricalHealthSamplesExportManager`, which uses SpeziHealthKit's Bulk Upload API to collect and batch-upload past health data
  - The underlying `BulkHealthExporter` manages the historical data collection
  - The collection and upload of historical data is not expected to complete in a single launch, and is specifically implemented in a way that allows it to run (slowly) in the background and process and upload the historical data batch-by-batch over the course of multiple app sessions
  - The API explicitly supports the app being killed while the data ingestion is running; the next launch will simply continue where the previous one left off



#### (Live) HealthKit Data Ingestion Pipeline

- The app does not upload live HealthKit samples immediately to the server
- Instead, it has a local buffer database, into which any new samples HealthKit delivers to the app are placed
- The app then keeps the samples in the buffer for around 3 days, and only then will upload them to the server
- The purpose of the buffer is to:
  1. Allow for on-device reconciliation of HealthKit deletions: if HealthKit informs us of a new sample at timestamp `T1`, and then informs us of a deletion at timestamp `T2 > T1`, if the deletion matches the sample added at `T1` and the sample is still in the local staging buffer, we can simply remove it from the buffer and never upload it, instead of having to upload the sample to the server and then also, separately inform the server of the deletion.
  2. Allow the app to (ideally) batch multiple samples belonging to the same sample type into a single upload, instead of having to run a bunch of individual single-sample uploads
- Any deletions HealthKit informs us about that don't match any existing samples in the upload buffer are written into a dedicated deletions buffer
- The app periodically runs an upload operation, which:
  1. takes all samples whose time in the buffer has exceeded the on-device retention period,
  2. batches them by sample type,
  3. uploads them to the server,
  4. removes them from the buffer.
- It also does the same for the deletion records
- When adding samples to the local buffer, the samples are converted into FHIR resources, which are then placed in the buffer (as JSON strings)
  - As part of the `HKSample` → FHIR conversion, MHC adjusts the resource as follows:
    - The `issued` date is set to the timestemp when the app ingested the `HKSample` (i.e., it represents the date the FHIR resource was issued, rather than the date the underlying `HKSample` was created)
    - FHIR extensions are added to the resource, storing:
      - The device's current time zone when the sample is collected
      - The currently-enrolled study revision
      - The current version and build number of the MHC app
- Each batch of samples being uploaded to the server is a single zstd-compressed JSON file.
  - The uploading is done using the `ManagedFileUpload` module; see below
- It is guaranteed that each batch is homogeneous, i.e., that all samples contained within a batch have the same sample type.
- HealthKit sample batches are uploaded to the following locations within firebase storage:
  - `/users/{uid}/liveHealthSamples/{sampleTypeId}_{uuid}.json.zstd` for all new samples being added to HealthKit after the user enrolled into the study;
  - `/users/{uid}/historicalHealthSamples/{sampleTypeId}_{uuid}.json.zstd` for the one-time upload of past historical HealthKit data
- Deletion records that have been in the buffer longer than the on-device retention period are also batched (into CSV files) and uploaded to the firebase storage backend
  - `/users/{uid}/healthDeletions/{sampleTypeId}_{uuid}.csv.zstd`
- All HealthKit-related files uploaded to storage (both for ingestion of new samples as well as for deletion records) have the following metadata fields set:
  - `batchStartDate`: the start date of the earliest sample in the batch
  - `batchEndDate`: the end date of the latest sample in the batch
  - `numSamples`: the number of samples in the batch


#### HealthKit Data Format

- All `HKSample`s are represnted as FHIR [Observation][R4Observation]s
- `HKClinicalRecord` samples are represented using their underlying FHIR resource provided to us by HealthKit
  - This can be either a R4 resource or a DSTU2
  - It can be any of the following resource types: AllergyIntolerance, Condition, Coverage, Immunization, MedicationOrder, MedicationRequest, MedicationStatement, MedicationDispense, Observation, Procedure, DiagnosticReport, or DocumentReference
  - In contrast to all other `HKSample`s, `HKClinicalRecord` samples are wrapped in a `{"version": "R4"|"DSTU2", "resource": {...}}` envelope


<details>
<summary>Example HKQuantitySample FHIR JSON</summary>

```json
{
  "code" : {
    "coding" : [
      {
        "code" : "8867-4",
        "display" : "Heart rate",
        "system" : "http://loinc.org"
      },
      {
        "code" : "364075005",
        "display" : "Heart rate",
        "system" : "http://snomed.info/sct"
      },
      {
        "code" : "HKQuantityTypeIdentifierHeartRate",
        "display" : "Heart Rate",
        "system" : "http://developer.apple.com/documentation/healthkit"
      }
    ]
  },
  "effectiveDateTime" : "2026-08-07T16:03:37.797878384-07:00",
  "extension" : [
    {
      "extension" : [
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceDevice/name",
          "valueString" : "Apple Watch"
        },
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceDevice/manufacturer",
          "valueString" : "Apple Inc."
        },
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceDevice/model",
          "valueString" : "Watch"
        },
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceDevice/hardwareVersion",
          "valueString" : "Watch7,12"
        },
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceDevice/softwareVersion",
          "valueString" : "26.5"
        }
      ],
      "url" : "https://bdh.stanford.edu/fhir/defs/sourceDevice"
    },
    {
      "extension" : [
        {
          "extension" : [
            {
              "url" : "https://bdh.stanford.edu/fhir/defs/sourceRevision/source/name",
              "valueString" : "Lukas' Apple Watch"
            },
            {
              "url" : "https://bdh.stanford.edu/fhir/defs/sourceRevision/source/bundleIdentifier",
              "valueString" : "com.apple.health.B83FE7C9-B62D-44D9-92A8-5CB2AE037A06"
            }
          ],
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceRevision/source"
        },
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceRevision/version",
          "valueString" : "31.2"
        },
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceRevision/productType",
          "valueString" : "Watch7,12"
        },
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/sourceRevision/OSVersion",
          "valueString" : "26.5.0"
        }
      ],
      "url" : "https://bdh.stanford.edu/fhir/defs/sourceRevision"
    },
    {
      "extension" : [
        {
          "url" : "https://bdh.stanford.edu/fhir/defs/metadata/HKMetadataKeyHeartRateMotionContext",
          "valueCoding" : {
            "code" : "1",
            "display" : "sedentary",
            "system" : "https://developer.apple.com/documentation/healthkit/hkheartratemotioncontext"
          }
        }
      ],
      "url" : "https://bdh.stanford.edu/fhir/defs/metadata"
    },
    {
      "url" : "https://bdh.stanford.edu/fhir/defs/sampleUploadTimeZone",
      "valueString" : "America/Los_Angeles"
    },
    {
      "extension" : [
        {
          "url" : "https://myheartcounts.stanford.edu/fhir/StructureDefinition/study-enrollment/study-id",
          "valueString" : "5D464372-C9A3-4018-A789-47149D934BFC"
        },
        {
          "url" : "https://myheartcounts.stanford.edu/fhir/StructureDefinition/study-enrollment/study-revision",
          "valueInteger" : 42
        }
      ],
      "url" : "https://myheartcounts.stanford.edu/fhir/StructureDefinition/study-enrollment"
    }
  ],
  "id" : "BDAC71F6-3398-4BDD-A56C-7BD50988D87A",
  "identifier" : [
    {
      "id" : "BDAC71F6-3398-4BDD-A56C-7BD50988D87A",
      "value" : "BDAC71F6-3398-4BDD-A56C-7BD50988D87A"
    }
  ],
  "issued" : "2026-08-07T16:04:59.340883016-07:00",
  "resourceType" : "Observation",
  "status" : "final",
  "valueQuantity" : {
    "code" : "/min",
    "system" : "http://unitsofmeasure.org",
    "unit" : "beats/minute",
    "value" : 84
  }
}
```
</details>


##### HKSample -> FHIR Observation mapping history
- Prior to MHC build 



### SensorKit

- MHC collects SensorKit data, if the user has opted in by granting us access
- SensorKit data is collected when the app is launched, as well as via a background `BGHealthResearchTask`
- In contrast to HealthKit, SensorKit does not offer a background "new data" observation API, and the app needs to handle this on its own
- Since the amount of data produced by SensorKit is significantly larger than what HealthKit produces, the app is not able to unconditionally store these data as FHIR resources, and instead employes a per-sensor encoding strategy (see the table below)
  - Low-density sensor streams are collected and uploaded as JSON-encoded FHIR [Observation][R4Observation]s
  - High-density sensor streams are instead collected and uploaded as CSV files containing the raw readings
- In contrast to HealthKit, the SensorKit data collection does not have an on-device buffer, and instead always uploads all data directly to the server
- The uploading happens using the `ManagedFileUpload` module, to the following locations in firebase storage:
  - `/users/{uid}/SensorKit/{sensorId}/{uuid}.{fileExt}`
- Each file uploaded by MHC's SensorKit data collection system sets the following metadata fields:
  - `batchStartDate`: the start date of the earliest sample in the batch
  - `batchEndDate`: the end date of the latest sample in the batch
  - `numSamples`: the number of samples in the batch


| Sensor           | Rate   | Upload |
| :--------------- | :----: | :----- |
| visits           | *todo* | JSON file with FHIR observations (`.json.zstd`) |
| onWrist          | *todo* | JSON file with FHIR observations (`.json.zstd`) |
| deviceUsage      | *todo* | JSON file with FHIR observations (`.json.zstd`) |
| ecg              | *todo* | JSON file with FHIR observations (`.json.zstd`) |
| wristTemperature | *todo* | CSV file per sample (`.csv.zstd`) |
| heartRate        | *todo* | CSV file per batch (`.csv.zstd`) |
| pedometer        | *todo* | CSV file per batch (`.csv.zstd`) |
| ambientLight     | *todo* | CSV file per batch (`.csv.zstd`) |
| accelerometer    | *todo* | CSV file per batch (`.csv.zstd`) |
| ambientPressure  | *todo* | CSV file per batch (`.csv.zstd`) |
| ppg              | *todo* | custom binary format (`.mhcPPG`) |



### Third-party wearable devices
- MHC allows the user to connect third-party wearable fitness/activity trackers, such as Fitbit, Withings, etc.
- This works by the user establishing a connection between their MHC account and their account with the third-party server, via the MHC account page in the iOS app
- The MHC backend then periodically ingests data from the third-party service (be it via push or pull), and stores it into the firebase storage, as FHIR-encoded samples, in line with how the HealthKit data is represented and stored


## File Uploading

- The `ManagedFileUpload` module is responsible for uploading files from the app to the server
- Other parts of the app (e.g., the HealthKit or SensorKit ingestion pipelines) hand files to `ManagedFileUpload`, which then schedules them for upload
- Upload scheduling is done by placing the to-be-uploaded files into a staging directory within the app's Documents folder
- The `ManagedFileUpload` module then simply works its way through these files, uploading each of them into firebase storage
- Uploads are written to `users/{uid}\{category}/{filename}`




## Client data needs

- in addition to querying on-device HealthKit data for upload to the backend, MHC also needs to query data for displaying it in the app, to the user
- we cannot rely only on querying local HealthKit data here, as this would miss any data that exists on the server but is not present in the client's HealthKit database:
  - data imported from third-party wearable services that don't already push their samples into the user's Health app
  - data manually entered by the user into the app, when we were not granted HealthKit write permissions


| Data | Needed By | Fetched From |
| :--- | :--- | :--- |
| Exercise Minutes          | HHD | Stats doc (`/users/{uid}/stats/exercise-time`) |
| Step Count                | HHD | Stats doc (`/users/{uid}/stats/steps`) |
| Sleep Stats               | HHD | Stats doc (`/users/{uid}/stats/sleep`) |
| Diet                      | HHD | `/users/{uid}/HealthObservations_MHCCustomSampleTypeDietMEPAScore/` |
| Nicotine Exposure         | HHD | `/users/{uid}/HealthObservations_MHCCustomSampleTypeNicotineExposure/` |
| Mental Well Being         | HHD | `/users/{uid}/HealthObservations_MHCCustomSampleTypeWHO5Score/` |
| Blood Pressure            | HHD | Stats doc (`/users/{uid}/stats/blood-pressure`) |
| LDL cholesterol           | HHD | Individual samples (`/users/{uid}/HealthObservations_MHCCustomSampleTypeBloodLipidMeasurement/`) |
| Blood Glucose (Fasting)   | HHD | Individual samples (`/users/{uid}/HealthObservations_MHCCustomSampleTypeBloodGlucoseFasting/`) |
| Blood Glucose (A1c)       | HHD | Individual samples (`/users/{uid}/HealthObservations_MHCCustomSampleTypeBloodGlucoseA1c/`) |
| BMI                       | HHD | Individual samples (`/users/{uid}/HealthObservations_HKQuantityTypeIdentifierBodyMassIndex/`) |
| Height                    | HHD | Individual samples (`/users/{uid}/HealthObservations_HKQuantityTypeIdentifierHeight/`) |
| Weight                    | HHD | Individual samples (`/users/{uid}/HealthObservations_HKQuantityTypeIdentifierBodyMass/`) |
| Past Timed Walk/Run tests | App | Individual samples (`/users/{uid}/HealthObservations_MHCHealthObservationTimedWalkingTestResultIdentifier/`) |




## User Data Statistics

- In order to drive certain in-app functionality (e.g., the health dashboard), the app needs statistics computed/derived from the user's data
- E.g.: the Heart Health Dashboard needs to know a bunch of data to compute its individual cardiovascular health scores
- Since we have data sources beyond the on-device HealthKit data, we cannot implement this the easy/trivial way (by simply running a local on-device HKStatisticsQuery)
- ...
- Solution: we maintain a series of well-known statistics documents, which store precomputed statistical values, that can be used by the client (eg the app) to compute whatever final statistics it needs
- The purpose of these documents is to enable the app to be able to fetch *all* of the data it displays to the user from the cloud backend, instead of performing local fetches from e.g. HalthKit.
- As such, we only need these stats documents for data that is being added into the app by multiple sources, and/or is not written directly into the firestore.


### What data do we need?

| Data | Need | Format |
| :--- | :--- | :--- |
| Exercise Minutes | HHD | Daily "number of active minutes" count |
| Step Count | HHD | Daily step count |
| Sleep Stats | HHD | Daily number of hours slept |
| Diet | HHD | Score computed from survey responses |
| Mental Well Being | HHD | Score computed from survey responses |
| Blood Pressure | HHD | Individual samples for sys/dia |
| LDL cholesterol | HHD | Individual samples |
| Blood Glucose (Fasting + A1c) | HHD | Individual samples |
| BMI | HHD | Individual samples |
| Noicotine Exposure | HHD | Score computed from survey responses |
| Past Timed Walk/Run tests | App | Individual samples |

Constraints:
- all data needs to go back at least 12 months
- since we have multiple potential data sources (HealthKit, Android Health Connect, Fitbit, Withings, etc), we need the data handling/processing/storage and stats computation to somehow work in a way that supports these multiple, competing data sources


### High-level structure
- we have special stats documents, at `/users/{uid}/stats/{metric}/{year}/{month}`, which contain hourly stats for a sample type for a month
  - e.g. `/users/{uid}/stats/steps/2026/08`
- each statistics document contains the following:
  - a `version` so we can easily evolve the structure down the road
  - the `metric` of the values in the document
  - `hourly`, containing the hourly stats
- different metrics' stats documents have different shapes, based on the speficic metric's shape and needs:
  - for non-cumulative metrics, the stats document is simply a list of individual samples
  - for cumulative metrics, the stats document contains 


#### Non-cumulative metric stats document

In the case of a non-cumulative sample type, each month's stats document contains a list of hourly min/max/avg readings.

Example: heart rate, at `/users/{uid}/stats/heart-rate/2026/08`

```jsonc
{
  "version": 0,
  "metric": "heart-rate",
  "hourly": {
    "com.apple.HealthKit": [
      // ...
      {
        "start": "2026-08-10T04:00:00-07:00",
        "end": "2026-08-10T05:00:00-07:00",
        "unit": "count/min",
        "min": "49",
        "max": "56",
        "avg": "52.423825347707634"
      },
      {
        "start": "2026-08-10T05:00:00-07:00",
        "end": "2026-08-10T06:00:00-07:00",
        "unit": "count/min",
        "min": "47.83707809448242",
        "max": "65",
        "avg": "55.85580520629883"
      },
      {
        "start": "2026-08-10T06:00:00-07:00",
        "end": "2026-08-10T07:00:00-07:00",
        "unit": "count/min",
        "min": "50",
        "max": "63",
        "avg": "54.875"
      },
      // ...
    ],
    "fitbit": [
      // ...
    ]
  }
}
```


#### Cumulative metric stats document

In the case of cumulative metrics (e.g., step count, exercise minutes, etc), each month's document simply contains a list of hourly sums.

Example: step count stats document, at `/users/{uid}/stats/steps/2026/08`
```jsonc
{
  "version": 0,
  "metric": "stepCount",
  "hourly": {
    "com.apple.HealthKit": [
      // ...
      {
        "start": "2026-08-10T07:00:00-07:00",
        "end": "2026-08-10T08:00:00-07:00",
        "unit": "count",
        "sum": "2288"
      },
      {
        "start": "2026-08-10T08:00:00-07:00",
        "end": "2026-08-10T09:00:00-07:00",
        "unit": "count",
        "sum": "350"
      },
      {
        "start": "2026-08-10T09:00:00-07:00",
        "end": "2026-08-10T10:00:00-07:00",
        "unit": "count",
        "sum": "34"
      },
      // ...
    ],
    "fitbit": [
      // ...
    ]
  }
}
```



| Sample Type             | Aggregation Mode | Aggregation Time Range |
| :---------------------- | :--------------: | :--------------------- |
| Step Count              | sum              | hourly                 |
| Heart Rate              | min/max/avg      | hourly                 |
| Exercise Minutes        | sum              | hourly                 |
| Sleep Stats             | sum              | daily                  |
| Diet                    | min/max/avg      | daily                  |
| Nicotine Exposure       | min/max/avg      | daily                  |
| Mental Well Being       | min/max/avg      | daily                  |
| Blood Pressure          | min/max/avg      | hourly                 |
| LDL cholesterol         | min/max/avg      | hourly                 |
| Blood Glucose (Fasting) | min/max/avg      | hourly                 |
| Blood Glucose (A1c)     | min/max/avg      | hourly                 |
| BMI                     | min/max/avg      | daily                  |
| Height                  | min/max/avg      | daily                  |
| Weight                  | min/max/avg      | hourly                 |



[R4QuestionnaireResponse]: https://hl7.org/fhir/R4/questionnaireresponse.html
[R4Observation]: https://hl7.org/fhir/R4/observation.html
