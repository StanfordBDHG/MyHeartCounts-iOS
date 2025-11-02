//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseStorage
import HealthKitOnFHIR
import OSLog
@preconcurrency import PDFKit.PDFDocument
import Spezi
import SpeziAccount
import SpeziFirebaseAccount
import SpeziFirestore
import SpeziHealthKit
import SpeziQuestionnaire
import SpeziSensorKit
import SpeziStudy
import SwiftUI


actor MyHeartCountsStandard: Standard, EnvironmentAccessible, AccountNotifyConstraint {
    // swiftlint:disable attributes
    @Application(\.logger) var logger
    @Dependency(HealthKit.self) var healthKit
    @Dependency(FirebaseConfiguration.self) var firebaseConfiguration
    @Dependency(StudyManager.self) var studyManager: StudyManager?
    @Dependency(Account.self) var account: Account?
    @Dependency(StudyBundleLoader.self) private var studyLoader
    @Dependency(TimeZoneTracking.self) private var timeZoneTracking: TimeZoneTracking?
    @Dependency(ManagedFileUpload.self) var managedFileUpload
    @Dependency(AccountFeatureFlags.self) private var accountFeatureFlags
    @Dependency(SetupTestEnvironment.self) private var setupTestEnvironment
    // swiftlint:disable attributes
    
    init() {}
    
    @MainActor
    func configure() {
        Task {
            await updateStudyDefinition()
            if let studyManager = await studyManager, !studyManager.studyEnrollments.isEmpty {
                await startClinicalRecordsCollection()
            }
        }
    }
    
    func updateStudyDefinition() async {
        guard let studyManager, let studyBundle = try? await studyLoader.update() else {
            return
        }
        logger.notice("Informing StudyManager about v\(studyBundle.studyDefinition.studyRevision) of MHC studyBundle")
        do {
            try await studyManager.informAboutStudies([studyBundle])
        } catch {
            logger.error("\(error)")
        }
    }
    
    // MARK: Account Stuff
    
    func respondToEvent(_ event: AccountNotifications.Event) async {
        let logger = logger
        switch event {
        case .deletingAccount:
            logger.notice("account is being deleted")
        case .disassociatingAccount:
            logger.notice("account is disassociating")
            // upon logging out, we want to throw the user back to the onboarding.
            // note that the onboarding flow, in this context, won't work 100% identical to when you've just launched the app in a non-logged-in state,
            // since the Firebase SDK and all related Spezi modules will still be loaded.
            // we could look into using the `FirebaseApp.deleteApp(_:)` API in combination with attempting to unload the related Spezi modules, but that
            // would be anything but trivial.
            // if the user wants to switch to a different region, the easiest approach currently is to just kill and relaunch the app.
            if !ProcessInfo.isBeingUITested, await !setupTestEnvironment.isInSetup {
                // ^we potentially log out and in as part of the test env setup; we want to skip this
                LocalPreferencesStore.standard[.onboardingFlowComplete] = false
            }
            try? ManagedFileUpload.clearPendingUploads()
            let studyManager = studyManager
            _ = await Task { @MainActor in
                // this works bc we only ever enroll into the MHC study.
                guard let studyManager, let enrollment = studyManager.studyEnrollments.first else {
                    return
                }
                logger.notice("unenrolling from study.")
                do {
                    try await studyManager.unenroll(from: enrollment)
                } catch {
                    logger.error("Error unenrolling from study: \(error)")
                }
                await stopClinicalRecordsCollection()
            }.result
        case .associatedAccount(let details):
            logger.notice("account was associated (account id: \(details.accountId))")
            try? await timeZoneTracking?.updateTimeZoneInfo()
        case .detailsChanged:
            break
        }
    }
}


extension MyHeartCountsStandard {
    func startClinicalRecordsCollection() async {
        let startDate = Calendar.current.date(byAdding: .year, value: -10, to: .now)
        for type in Self.allRecordTypes {
            let collector = CollectSample(
                type,
                start: .automatic,
                continueInBackground: true,
                timeRange: startDate.map { .startingAt($0) } ?? .newSamples
            )
            await healthKit.addHealthDataCollector(collector)
        }
    }
    
    func stopClinicalRecordsCollection() async {
        for type in Self.allRecordTypes {
            await healthKit.resetSampleCollection(for: type)
        }
    }
}


extension MyHeartCountsStandard: NotificationHandler {
    nonisolated func receiveIncomingNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions? {
        // we want notifications to always display, even when the app is running.
        [.badge, .banner, .list, .sound]
    }
}


extension MyHeartCountsStandard {
    func uploadSensorKitFile(at url: URL, for sensor: Sensor<some Any>) {
        managedFileUpload.scheduleForUpload(url, category: ManagedFileUpload.Category(sensor))
    }
}
