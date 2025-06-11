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
    
    var body: some View {
        OnboardingView(
            title: "MyHeart Counts",
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
                onboardingPath.nextStep()
            }
        )
    }
}


#if DEBUG
#Preview {
    ManagedNavigationStack {
        Welcome()
    }
}
#endif
