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
import SwiftUI


struct FinalEnrollmentStep: View {
    @Environment(OnboardingNavigationPath.self)
    private var path
    @Environment(StudyManager.self)
    private var studyManager
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "My Heart Counts")
        } contentView: {
            Text("You're all set.\n\nGreat to have you on board!")
        } actionView: {
            OnboardingActionsView("Complete") {
                path.nextStep()
                try await studyManager.enroll(in: mockMHCStudy)
            }
        }
    }
}
