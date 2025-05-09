//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziNotifications
import SpeziOnboarding
import SpeziStudy
import SpeziViews
import SwiftUI


struct FinalEnrollmentStep: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    @Environment(StudyManager.self)
    private var studyManager
    
    @Environment(HistoricalHealthSamplesExportManager.self)
    private var historicalUploadManager
    
    @Environment(StudyDefinitionLoader.self)
    private var studyLoader
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "My Heart Counts")
        } content: {
            Text("You're all set.\n\nGreat to have you on board!")
        } footer: {
            OnboardingActionsView("Complete") {
                await completeStudyEnrollment()
            }
            .disabled(viewState != .idle)
        }
    }
    
    private func completeStudyEnrollment() async {
        guard let study = try? studyLoader.studyDefinition?.get() else {
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
