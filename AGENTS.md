# AGENTS.md


## Summary

My Heart Counts (MHC) is an iOS app that implement a mobile cardiovascular health study.

Participants can download the iOS app, enroll into the study, and share certain types of data with the research team:
- health observations (obtained from HealthKit)
- questionnaire responses (obtained by prompting the patient to fill out a survey directly in the app)
- active task results (obtained by having the patient perform an active task, such as eg a Six Minute Walk Test, directly in the app)
- raw device sensor streams (obtained from SensorKit)

The MHC app itself, for the most part, is not aware of the specific study protocol, and instead fetches a StudyBundle from the backend.
The StudyBundle, consisting of a StudyDefinition and resources referenced by the StudyDefinition, is then used to dynamically configure some aspects of the app and populate it with data.



## Code
- `MyHeartCounts/`: the iOS app
- `MyHeartCountsWatchApp/`: the watch companion target
- `MyHeartCountsShared/`: a small SPM package containing code that is shared between the iOS app and the watch app
    - `MyHeartCountsShared/Tests`: unit tests of the utils package
- `MyHeartCountsTests/`: MHC unit tests
- `MyHeartCountsUITests/`: MHC UI tests
- `MyHeartCounts-Firebase`: git submodule containing the MHC firebase environment
- `MyHeartCounts-StudyDefinitions`: git submodule containing the MHCStudyDefinition SPM package



## Build / Test / Lint
- MHC iOS app:
    - building the app: `fastlane build`
    - running a specific UI test: `xcrun xcodebuild test -project MyHeartCounts.xcodeproj -scheme MyHeartCounts -testPlan "MyHeartCounts UI Tests" -only-testing:MyHeartCountsUITests/<TestClass>/<testMethod> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
- MyHeartCountsShared SPM package:
    - in the `MyHeartCountsShared/` folder: `swift build` / `swift test`
- linting: `swiftlint`



## Architecture
- MHC is implemented as a [Spezi](https://github.com/StanfordSpezi/Spezi) app
- core functionality within the app is decomposed into Spezi modules
    - some of these are loaded into the app directly at launch
    - the rest (i.e., those who depend on a firebase environment being present) are loaded dynamically when firebase is loaded
    - these modules depend on each other, via Spezi's @Dependency mechamism.
- Firebase / backend:
    - MHC uses a Firebase backend, for: user management, retrieving Study Definitions (used to configure the app), storing and persisting data collected from the participant
    - the app connects to a different backend depending on which variant of the study (US vs UK) the user enrolled in (which is based on the user's country selection during the onboarding)
- key components:
    - task scheduling
    - task performing
    - data collection (HealthKit and SensorKit)
- component: task scheduling:
    - MHC uses SpeziStudy and SpeziScheduler to model the study components as user-actionable tasks
    - MHC downloads the current StudyDefinition from the firebase backend, and informs SpeziStudy about it, which then uses the study components and schedules declared within the StudyDefinition to build up SpeziScheduler tasks, which MHC then queries for and displays to the user
- component: task performing:
    - the `@PerformTask` property wrapper is used to coordinate the handling of performing tasks.
    - questionnaire tasks are handled by presenting the questionnaire to the user, collecting responses as a FHIR value, and uploading that to the backend
    - informative article tasks are handled by displaying the informative article to the user
    - active tasks (e.g., timed walk/run tests, or ECGs) are handled by displaying the task's specific UI
- component: data collection:
    - all data provided by the user is persisted to the backend, and associated with the user from whom it was collected
    - where possible, data is represented as FHIR R4 resources and stored in a JSON format
    - this covers:
        - data that were manually entered by the user (e.g., questionnaire responses)
        - data that were computed based on user actions (e.g., Timed Walk/Run Test results)
        - data collected from a device sensor and read from a dedicated API (e.g., HealthKit and SensorKit)
    - HealthKit:
        - MHC collects HealthKit data from the user, for a range of sample types
        - the actual list of sample types for which data should be collected is read from the StudyDefinition (this also allows it to be updated by pushing out a new revision of the StudyDefinition)
        - MHC uses SpeziHealthKit to set up and manage the background data collection
        - the MyHeartCountsStandard is informed by SpeziHealthKit about new and deleted samples, and propagates both additions and deletions to the backend
    - SensorKit:
        - MHC optionally allows the user to opt in to sharing SensorKit data with the study team
        - the `SensorKitDataFetcher` module implements the automatic, anchored fetching, FHIR-converting, and uploading of SensorKit data
        - the module uses different upload strategies for different sensors, based on the sensor's expected amount of data, and the shape of the sensor's samples
- background tasks:
    - MHC registers several background tasks with iOS, which are triggered by the OS periodically and are given small amounts of background-execution time
    - HealthKit: MHC uses HealthKit background delivery to be notified by iOS when new HealthKit data is available
    - AppRefresh: runs a couple of times per day to update the study definition
- HealthUploadStaging:
    - the `HealthUploadStaging` module acts as a local persistence layer for buffering new/deleted HealthKit samples before they are persisted to the backend
    - the module obtains new samples and deletions from the MyHeartCountsStandard, and persists them into a small on-device SQLite database
    - it then enforces a 3-day retention period, where the samples are kept locally, before uploading them to the backend
    - this allows new deletion records that match existing samples currently in the pendingUpload state to be locally reconciled against the sample, allowing both the sample and the deletion record to be elided
    - samples that have been in the local database longer than the retention period are batched and uploaded as compressed JSON files
- File Upload:
    - the `ManagedFileUpload` module implements generic file upload support
    - other parts of the app can submit files they wish to upload to a local queue mansged by the module
    - it then works through that queue, whenever the app is running and also in the background, to ensure that everything gets uploaded eventually
    - the motivation here is not making other parts of the app (eg, HealthKit/SensorKit data collection) wait until the data they have collected has been uploaded
        - for example, HealthKit background delivery typically is limited to 30 seconds, so the app needs to focus on fetching the new samples, and can defer the actual upload until a later, more generic background task



## Other
- Localization (app-level):
    - the app is localized into the following languages: English (US), English (UK), Spanish
    - localization is done using Localizable.xcstrings string catalogues
    - if an entry in the localizations catalogue uses a key that is not human-readable (e.g., `ONBOARDING_TITLE`), it must have explicit translations for all languages (including english)
    - if an entry uses a key that is human-readable english, the English (US) and English(UK) translations may be omitted
    - all entries containing text that is different in US vs UK english must have dedicated translations for both languages
- Localization (study-level):
    - within a StudyBundle, localization is handled by providing multiple versions of each localized resource, and then dynamically selecting the best match
    - for files, this means that a localized `PHQ0.json` questionnaire would actually exist as several files: `PHQ9+en-US.json`, `PHQ9+en-GB.json`, etc
- Localization (Other)
    - The app is deployed to users in different regions of the world. No sssumptions should be made wrt region, and all user-visible elements should use appropriate iOS APIs that produce locale-aware output, e.g., when formatting numbers.
    - This also extends to units: the app should never assume that the user wants metric or US or imperial units; instead it should use appropriate locale-based units.
- MHC uses SwiftLint to enforce code style rules
    - during development, the SwiftLint checks don't need to always perfectly pass; it is ok for warnings to exist in code that is actively being worked on
    - SwiftLint warnings/errors are required to be fully resolved when code is actually about to be merged into the main branch
- Prefer the Observation framework (`@Observable`, etc) over legacy Combine-based `@ObservedObject`, `ObservableObject`, etc
- `Swift::Task` is valid Swift, as of Swift 6.3. It is a *module selector*; it allows referring to a symbol by explicitly specifying its parent module; it is typically used to resolve ambiguous lookups.
- Read the app's deployment target from the xcodeproj file and take that constraint into account when dealing with availability-limited code.


NO YAPPING!!!!!!!
