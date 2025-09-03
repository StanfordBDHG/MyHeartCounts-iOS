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
import SpeziStudy
import SwiftUI


actor MyHeartCountsStandard: Standard, EnvironmentAccessible, AccountNotifyConstraint {
    // swiftlint:disable attributes
    @Application(\.logger) var logger
    @Dependency(FirebaseConfiguration.self) var firebaseConfiguration
    @Dependency(StudyManager.self) private var studyManager
    @Dependency(Account.self) var account: Account?
    @Dependency(StudyBundleLoader.self) private var studyLoader
    @Dependency(TimeZoneTracking.self) private var timeZoneTracking: TimeZoneTracking?
    @Dependency(HealthDataFileUploadManager.self) var healthDataUploader
    @Dependency(AccountFeatureFlags.self) private var accountFeatureFlags
    @Dependency(SetupTestEnvironment.self) private var setupTestEnvironment
    // swiftlint:disable attributes
    
    init() {}
    
    @MainActor
    func configure() {
        Task {
            await logger.notice("STUDIES:")
            for enrollment in await studyManager.studyEnrollments {
                await logger.notice("- \(enrollment.studyBundle?.studyDefinition.metadata.title ?? "uhhh")")
            }
            if let studyBundle = try? await studyLoader.update() {
                await logger.notice("Informing StudyManager about v\(studyBundle.studyDefinition.studyRevision) of MHC studyBundle")
                try await studyManager.informAboutStudies([studyBundle])
            }
        }
    }
    
    private func propagateDebugModeValue(_ isEnabled: Bool) async {
        LocalPreferencesStore.standard[.lastSeenIsDebugModeEnabledAccountKey] = isEnabled
        await accountFeatureFlags._updateIsDebugModeEnabled(isEnabled)
    }
    
    private func propagateDebugModeValue(_ details: AccountDetails) async {
        await propagateDebugModeValue(details.enableDebugMode ?? false)
    }
    
    func respondToEvent(_ event: AccountNotifications.Event) async {
        let logger = logger
        switch event {
        case .deletingAccount:
            logger.notice("account is being deleted")
            await propagateDebugModeValue(false)
        case .disassociatingAccount:
            logger.notice("account is disassociating")
            await propagateDebugModeValue(false)
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
            // QUESTION deleting the userDocument will probably also delete everything nested w/in it (eg: Questionnaire Resonse
            // NOTE: we want as many of these as possible to succeed; hence why we use try? everywhere...
            try? FileManager.default.removeItem(at: .scheduledLiveHealthKitUploads)
            try? FileManager.default.removeItem(at: .scheduledHistoricalHealthKitUploads)
            try? await firebaseConfiguration.userDocumentReference.delete()
            let studyManager = studyManager
            await MainActor.run {
                guard let enrollment = studyManager.studyEnrollments.first else { // this works bc we only ever enroll into the MHC study.
                    return
                }
                logger.notice("unenrolling from study.")
                do {
                    try studyManager.unenroll(from: enrollment)
                } catch {
                    logger.error("Error unenrolling from study: \(error)")
                }
            }
        case .associatedAccount(let details):
            logger.notice("account was associated")
            await propagateDebugModeValue(details)
            try? await timeZoneTracking?.updateTimeZoneInfo()
        case .detailsChanged(_, let newDetails):
            logger.notice("account details changed")
            await propagateDebugModeValue(newDetails)
        }
    }
}
