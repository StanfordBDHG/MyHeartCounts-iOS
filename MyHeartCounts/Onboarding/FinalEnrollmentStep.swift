//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziFoundation
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
    @Environment(HistoricalHealthSamplesExportManager.self) private var historicalUploadManager
    @Environment(StudyBundleLoader.self) private var studyLoader
    // swiftlint:enable attributes
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "Welcome to My Heart Counts")
        } content: {
            let doc = MarkdownDocument(
                metadata: [:],
                blocks: [.markdown(id: nil, rawContents: loadText())]
            )
            MarkdownView(markdownDocument: doc)
        } footer: {
            OnboardingActionsView("Complete") {
                await completeStudyEnrollment()
            }
            .disabled(viewState != .idle)
        }
    }
    
    private func loadText() -> String {
        var text = String(localized: "FINAL_ENROLLMENT_STEP_MESSAGE")
        if onboardingData.consentResponses?.selects["short-term-physical-activity-trial"] == "short-term-physical-activity-trial-yes" {
            text.append("\n\n")
            text.append(String(localized: "FINAL_ENROLLMENT_STEP_MESSAGE_TRIAL_SECTION"))
        }
        text.append("\n\n")
        text.append(String(localized: "FINAL_ENROLLMENT_STEP_MESSAGE_FOOTER"))
        return text
    }
    
    private func completeStudyEnrollment() async {
        guard let study = try? studyLoader.studyBundle?.get() else {
            // guaranteed to be non-nil if we end up in this view
            return
        }
        do {
            try await studyManager.enroll(in: study)
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
