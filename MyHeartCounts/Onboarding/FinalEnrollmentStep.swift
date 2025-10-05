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
import SpeziNotifications
import SpeziOnboarding
import SpeziStudy
import SpeziViews
import SwiftUI


private struct FinalEnrollmentGridRow: View {
    let icon: SFSymbol
    let text: LocalizedStringResource
    
    var body: some View {
        GridRow {
            Image(systemSymbol: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
                .foregroundStyle(.tint)
                .gridCellAnchor(.topLeading)
                .frame(width: 42, alignment: .topLeading)
            HStack {
                Text(text)
                    .font(.title3)
                    .lineLimit(32)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
                Spacer()
            }
        }
    }
}

struct FinalEnrollmentStep: View {
    // swiftlint:disable attributes
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(OnboardingDataCollection.self) private var onboardingData
    @Environment(StudyManager.self) private var studyManager
    @Environment(Account.self) private var account
    @Environment(HistoricalHealthSamplesExportManager.self) private var historicalUploadManager
    @Environment(StudyBundleLoader.self) private var studyLoader
    // swiftlint:enable attributes
    
    @State private var viewState: ViewState = .idle
    
    
    private var showTrialSection: Bool {
        onboardingData.consentResponses?.selects["short-term-physical-activity-trial"] == "short-term-physical-activity-trial-yes"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to My Heart Counts")
                    .font(.title2.bold())
                    .multilineTextAlignment(.leading)
                    .lineLimit(12)
                content
                OnboardingActionsView("Start") {
                    await completeStudyEnrollment()
                }
                    .disabled(viewState != .idle)
            }
            .padding(.horizontal)
        }
            .scrollBounceBehavior(.basedOnSize)
    }
    
    @ViewBuilder private var content: some View {
        Text("What happens next:")
            .font(.title3)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.secondary)
            .padding(.bottom)
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            FinalEnrollmentGridRow(
                icon: SFSymbol(rawValue: "7.calendar"),
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_SEVEN_DAYS"
            )
            FinalEnrollmentGridRow(
                icon: .deskclock,
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_EVERY_DAY"
            )
            FinalEnrollmentGridRow(
                icon: .chartLineTextClipboard,
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_DATA_COLLECTION"
            )
            if showTrialSection {
                FinalEnrollmentGridRow(
                    icon: .calendarBadgeClock,
                    text: "FINAL_ENROLLMENT_STEP_MESSAGE_BASELINE"
                )
            }
            FinalEnrollmentGridRow(
                icon: SFSymbol(rawValue: "arrow.up.heart"),
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_FOOTER"
            )
        }
    }
    
    
    private func completeStudyEnrollment() async {
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
            Task(priority: .background) {
                historicalUploadManager.startAutomaticExportingIfNeeded()
            }
        } catch StudyManager.StudyEnrollmentError.alreadyEnrolledInNewerStudyRevision {
            // NOTE(@lukas) make this an error in non-debug versions!
        } catch {
            viewState = .error(error)
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
            MyHeartCountsStandard.previewModels
            HistoricalHealthSamplesExportManager()
            BulkHealthExporter()
        }
}
