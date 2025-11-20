//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseAuth
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
import SpeziLocalStorage
import SpeziQuestionnaire
import SpeziScheduler
import SpeziSensorKit
import SpeziStudy
import SwiftUI


actor MyHeartCountsStandard: Standard, EnvironmentAccessible, AccountNotifyConstraint {
    struct SimpleError: Error {
        let message: String
    }
    
    // swiftlint:disable attributes
    @Application(\.logger) var logger
    @Dependency(HealthKit.self) var healthKit
    @Dependency(FirebaseConfiguration.self) var firebaseConfiguration
    @Dependency(StudyManager.self) var studyManager: StudyManager?
    @Dependency(Account.self) var account: Account?
    @Dependency(LocalStorage.self) private var localStorage
    @Dependency(StudyBundleLoader.self) private var studyLoader
    @Dependency(TimeZoneTracking.self) private var timeZoneTracking: TimeZoneTracking?
    @Dependency(ManagedFileUpload.self) var managedFileUpload
    @Dependency(AccountFeatureFlags.self) private var accountFeatureFlags
    @Dependency(SetupTestEnvironment.self) private var setupTestEnvironment
    @Dependency(HistoricalHealthSamplesExportManager.self) private var historicalUploadManager
    @Dependency(NotificationTracking.self) var notificationTracking
    @Dependency(Scheduler.self) var scheduler
    @Dependency(HistoricalHealthSamplesExportManager.self) private var historicalHealthDataUploadMgr
    @Dependency(SensorKitDataFetcher.self) private var sensorKitFetcher
    // swiftlint:disable attributes
    
    init() {}
    
    @MainActor
    func configure() {
        _Concurrency.Task {
            await handleIsLoggedOut()
            await updateStudyDefinition()
        }
    }
    
    @MainActor
    private func handleIsLoggedOut() async {
        let isLoggedIn1 = Auth.auth().currentUser != nil
        let isLoggedIn2 = await account?.signedIn ?? false
        if !isLoggedIn1 && !isLoggedIn2 {
            // both firebase and SpeziAccount tell us that there currently is no logged-in user.
            do {
                try await performLogoutCleanup()
            } catch {
                await logger.error("\(#function): \(error)")
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
    
    func enroll(in studyBundle: StudyBundle) async throws {
        guard let account, let studyManager else {
            throw SimpleError(message: "Missing Account / StudyManager")
        }
        do {
            if let enrollmentDate = await account.details?.dateOfEnrollment {
                // the user already has enrolled at some point in the past.
                // we now explicitly specify this enrollment date, to make sure the StudyManager
                // can schedule all study components relative to that.
                try await studyManager.enroll(in: studyBundle, enrollmentDate: enrollmentDate)
            } else {
                let enrollmentDate = Date.now
                try await studyManager.enroll(in: studyBundle, enrollmentDate: enrollmentDate)
                do {
                    var newDetails = AccountDetails()
                    newDetails.dateOfEnrollment = enrollmentDate
                    let modifications = try AccountModifications(modifiedDetails: newDetails)
                    try await account.accountService.updateAccountDetails(modifications)
                }
            }
            try localStorage.store(.now, for: .studyActivationDate)
            _Concurrency.Task(priority: .background) {
                historicalUploadManager.startAutomaticExportingIfNeeded()
            }
        } catch StudyManager.StudyEnrollmentError.alreadyEnrolledInNewerStudyRevision {
            // should be unreachable, but we'll handle this as a non-error just to be safe.
        } catch {
            throw error
        }
    }
    
    // MARK: Account Stuff
    
    func respondToEvent(_ event: AccountNotifications.Event) async {
        print("ACCOUNT EVENT \(event)")
        let logger = logger
        switch event {
        case .deletingAccount:
            logger.notice("account is being deleted")
        case .disassociatingAccount:
            logger.notice("account is disassociating")
            try? await performLogoutCleanup()
        case .associatedAccount(let details):
            logger.notice("account was associated (account id: \(details.accountId))")
            try? await timeZoneTracking?.updateTimeZoneInfo()
        case .detailsChanged:
            break
        }
    }
    
    
    @MainActor
    private func performLogoutCleanup() async throws {
        // upon logging out, we want to throw the user back to the onboarding.
        // note that the onboarding flow, in this context, won't work 100% identical to when you've just launched the app in a non-logged-in state,
        // since the Firebase SDK and all related Spezi modules will still be loaded.
        // we could look into using the `FirebaseApp.deleteApp(_:)` API in combination with attempting to unload the related Spezi modules, but that
        // would be anything but trivial.
        // if the user wants to switch to a different region, the easiest approach currently is to just kill and relaunch the app.
        try? await managedFileUpload.clearPendingUploads()
        try? await historicalUploadManager.fullyResetSession(restart: false)
        await sensorKitFetcher.resetAllQueryAnchors()
        let studyManager = await studyManager
        _ = await _Concurrency.Task { @MainActor in
            guard let studyManager else {
                return
            }
            await logger.notice("unenrolling from study.")
            // there should only ever be one enrollment (the MHC one)
            for enrollment in studyManager.studyEnrollments {
                do {
                    try await studyManager.unenroll(from: enrollment)
                } catch {
                    await logger.error("Error unenrolling from study: \(error)")
                }
            }
        }.result
        _Concurrency.Task {
            guard /*!ProcessInfo.isBeingUITested,*/ await !setupTestEnvironment.isInSetup else {
                // ^we potentially log out and in as part of the test env setup; we want to skip this
                return
            }
            // it seems that the fact that the account sheet typically is still presented while logging out causes issues with us setting the
            // `onboardingFlowComplete` UserDefaults key being set to true (likely bc the other sheet still being presented prevents SwiftUI from presenting the
            // onboarding sheet, thereby causing it to set the UserDefaults key (which, via a Binding, is used as the onboarding sheet's `isPresented` value)
            // back to false.
            // We try to work around this by waiting a bit, to give the account sheet a chance to dismiss itself.
            try await _Concurrency.Task.sleep(for: .seconds(2))
            await logger.notice("Triggering Onboarding Flow")
            LocalPreferencesStore.standard[.onboardingFlowComplete] = false
        }
    }
}


extension MyHeartCountsStandard {
    func uploadSensorKitFile(at url: URL, for sensor: Sensor<some Any>) {
        managedFileUpload.scheduleForUpload(url, category: ManagedFileUpload.Category(sensor))
    }
}
