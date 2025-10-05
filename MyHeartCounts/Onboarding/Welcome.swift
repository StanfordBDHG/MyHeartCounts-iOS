//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import Spezi
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct Welcome: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var onboardingPath
    
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    OnboardingHeader(
                        title: "My Heart Counts",
                        description: "WELCOME_SUBTITLE"
                    )
                    onboardingInformationView
                }
                .padding(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize)
            Spacer(minLength: 8)
                .border(Color.blue, width: 1)
            OnboardingActionsView("Continue") {
                onboardingPath.nextStep()
            }
        }
    }
    
    private var onboardingInformationView: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            OnboardingIconGridRow(
                icon: .appBadge,
                text: "WELCOME_AREA1_DESCRIPTION"
            )
            OnboardingIconGridRow(
                icon: .wandAndSparklesInverse,
                text: "WELCOME_AREA2_DESCRIPTION"
            )
            OnboardingIconGridRow(
                icon: .watchfaceApplewatchCase,
                text: "WELCOME_AREA3_DESCRIPTION"
            )
        }
    }
}


#Preview {
    ManagedNavigationStack {
        Welcome()
    }
}
