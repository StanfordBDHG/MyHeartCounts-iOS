//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import Spezi
import SpeziAccount
import SpeziConsent
import SpeziFoundation
import SpeziHealthKitBulkExport
import SpeziLocalStorage
import SpeziNotifications
import SpeziOnboarding
import SpeziStudy
import SpeziViews
import SwiftUI


struct FinalEnrollmentStep: View {
    // swiftlint:disable attributes
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(OnboardingDataCollection.self) private var onboardingData
    @Environment(StudyManager.self) private var studyManager
    @Environment(Account.self) private var account
    @Environment(HistoricalHealthSamplesExportManager.self) private var historicalUploadManager
    @Environment(StudyBundleLoader.self) private var studyLoader
    @LocalStorageEntry(.studyActivationDate) private var studyActivationDate
    // swiftlint:enable attributes
    
    @State private var viewState: ViewState = .idle
    
    
    private var showTrialSection: Bool {
        onboardingData.consentResponses?.selects["short-term-physical-activity-trial"] == "short-term-physical-activity-trial-yes"
    }
    
    var body: some View {
        OnboardingPage(title: "Welcome to My Heart Counts", description: "What happens next:") {
            content
        } footer: {
            OnboardingActionsView("Start", viewState: $viewState) {
                try await completeStudyEnrollment()
            }
        }
        .navigationBarBackButtonHidden(viewState != .idle)
    }
    
    @ViewBuilder private var content: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            let calendarSymbol = if #available(iOS 26, *) {
                SFSymbol(rawValue: "7.calendar")
            } else {
                SFSymbol.calendar
            }
            OnboardingIconGridRow(
                icon: calendarSymbol,
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_SEVEN_DAYS"
            )
            OnboardingIconGridRow(
                icon: .deskclock,
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_EVERY_DAY"
            )
            OnboardingIconGridRow(
                icon: .chartLineTextClipboard,
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_DATA_COLLECTION"
            )
            if showTrialSection {
                OnboardingIconGridRow(
                    icon: .calendarBadgeClock,
                    text: "FINAL_ENROLLMENT_STEP_MESSAGE_BASELINE"
                )
            }
            OnboardingIconGridRow(
                icon: SFSymbol(rawValue: "arrow.up.heart"),
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_FOOTER"
            )
        }
        .padding(.leading)
    }
    
    
    private func completeStudyEnrollment() async throws {
        guard let study = try? studyLoader.studyBundle?.get() else {
            // guaranteed to be non-nil if we end up in this view
            return
        }
        do {
            if let enrollmentDate = account.details?.dateOfEnrollment {
                // the user already has enrolled at some point in the past.
                // we now explicitly specify this enrollment date, to make sure the StudyManager
                // can schedule all study components relative to that.
                try await studyManager.enroll(in: study, enrollmentDate: enrollmentDate)
            } else {
                let enrollmentDate = Date.now
                try await studyManager.enroll(in: study, enrollmentDate: enrollmentDate)
                do {
                    var newDetails = AccountDetails()
                    newDetails.dateOfEnrollment = enrollmentDate
                    let modifications = try AccountModifications(modifiedDetails: newDetails)
                    try await account.accountService.updateAccountDetails(modifications)
                }
            }
            studyActivationDate = .now
            Task(priority: .background) {
                historicalUploadManager.startAutomaticExportingIfNeeded()
            }
        } catch StudyManager.StudyEnrollmentError.alreadyEnrolledInNewerStudyRevision {
            // should be unreachable, but we'll handle this as a non-error just to be safe.
        } catch {
            throw error
        }
        path.nextStep()
    }
}


#Preview {
    ManagedNavigationStack {
        FinalEnrollmentStep()
    }
    .environment(OnboardingDataCollection())
    .environment(StudyBundleLoader.shared)
    .previewWith(standard: MyHeartCountsStandard()) {
        MyHeartCounts.previewModels
        HistoricalHealthSamplesExportManager()
        BulkHealthExporter()
    }
}
