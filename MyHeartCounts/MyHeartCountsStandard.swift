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
    @Application(\.logger)
    private var logger
    
    @Dependency var firebaseConfiguration = FirebaseConfiguration(setupTestAccount: FeatureFlags.setupTestAccount)
    
    @Dependency(StudyManager.self)
    private var studyManager: StudyManager?
    
    @Dependency(Account.self)
    var account: Account?
    
    @Dependency(StudyBundleLoader.self)
    private var studyLoader
    
    @Dependency(TimeZoneTracking.self)
    private var timeZoneTracking: TimeZoneTracking?
    
    @Dependency(HealthDataFileUploadManager.self)
    var healthDataUploader
    
    var enableDebugMode: Bool {
        LocalPreferencesStore.standard[.enableDebugMode]
    }
    
    init() {}
    
    
    @MainActor
    func configure() {
        Task {
            if let studyManager = await self.studyManager,
               let studyBundle = try? await studyLoader.update() {
                await logger.notice("Informing StudyManager about v\(studyBundle.studyDefinition.studyRevision) of MHC studyBundle")
                try await studyManager.informAboutStudies([studyBundle])
            }
        }
    }

    func respondToEvent(_ event: AccountNotifications.Event) async {
        switch event {
        case .deletingAccount:
            break
        case .disassociatingAccount:
            // upon logging out, we want to throw the user back to the onboarding.
            // note that the onboarding flow, in this context, won't work 100% identical to when you've just launched the app in a non-logged-in state,
            // since the Firebase SDK and all related Spezi modules will still be loaded.
            // we could look into using the `FirebaseApp.deleteApp(_:)` API in combination with attempting to unload the related Spezi modules, but that
            // would be anything but trivial.
            // if the user wants to switch to a different region, the easiest approach currently is to just kill and relaunch the app.
            LocalPreferencesStore.standard[.onboardingFlowComplete] = false
            // QUESTION deleting the userDocument will probably also delete everything nested w/in it (eg: Questionnaire Resonse
            // NOTE: we want as many of these as possible to succeed; hence why we use try? everywhere...
            try? FileManager.default.removeItem(at: .scheduledLiveHealthKitUploads)
            try? FileManager.default.removeItem(at: .scheduledHistoricalHealthKitUploads)
            try? await firebaseConfiguration.userDocumentReference.delete()
            if let studyManager {
                await MainActor.run {
                    guard let enrollment = studyManager.studyEnrollments.first else { // this works bc we only ever enroll into the MHC study.
                        return
                    }
                    try? studyManager.unenroll(from: enrollment)
                }
            }
        case .associatedAccount:
            try? await timeZoneTracking?.updateTimeZoneInfo()
        case .detailsChanged:
            break
        }
    }
}
