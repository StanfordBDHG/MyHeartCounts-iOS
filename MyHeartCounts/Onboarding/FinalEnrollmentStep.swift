//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
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
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "My Heart Counts")
        } content: {
            Text("You're all set.\n\nGreat to have you on board!")
        } footer: {
            OnboardingActionsView("Complete") {
                do {
                    try await studyManager.enroll(in: mockMHCStudy)
                    Task(priority: .background) {
                        historicalUploadManager.startAutomaticExportingIfNeeded()
                    }
                } catch StudyManager.StudyEnrollmentError.alreadyEnrolledInNewerStudyRevision {
                    // NOTE(@lukas) make this an error in non-debug versions!
                } catch {
                    throw error
                }
                path.nextStep()
            }
        }
    }
}
