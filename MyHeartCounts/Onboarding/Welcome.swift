//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct Welcome: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var onboardingPath
    
    @Environment(StudyDefinitionLoader.self)
    private var studyLoader
    
    var body: some View {
        OnboardingView(
            title: "My Heart Counts",
            subtitle: "WELCOME_SUBTITLE",
            areas: [
                OnboardingInformationView.Content(
                    icon: {
                        Image(systemName: "apps.iphone")
                            .accessibilityHidden(true)
                    },
                    title: "The Spezi Framework",
                    description: "WELCOME_AREA1_DESCRIPTION"
                ),
                OnboardingInformationView.Content(
                    icon: {
                        Image(systemName: "shippingbox.fill")
                            .accessibilityHidden(true)
                    },
                    title: "Swift Package Manager",
                    description: "WELCOME_AREA2_DESCRIPTION"
                ),
                OnboardingInformationView.Content(
                    icon: {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .accessibilityHidden(true)
                    },
                    title: "Spezi Modules",
                    description: "WELCOME_AREA3_DESCRIPTION"
                )
            ],
            actionText: "Learn More",
            action: {
                goToNextStep()
            }
        )
    }
    
    private func goToNextStep() {
        switch studyLoader.studyDefinition {
        case .success:
            // we have successfully loaded a study definition and can safely proceed to the next step.
            // all upcoming ordinary navigation steps are allowed to assume that there exists a non-nil
            // study definition in the `StudyDefinitionLoader`.
            // Note that we don't actually need to perform any loading on our own here; the StudyDefinitionLoader
            // will automatically try to load the study as part of its configuration() step.
            onboardingPath.nextStep()
        case nil, .failure:
            onboardingPath.append(customView: UnableToLoadStudyDefinitionStep())
        }
    }
}


#if DEBUG
#Preview {
    ManagedNavigationStack {
        Welcome()
    }
}
#endif
