//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(APISupport)
import Spezi
import SpeziOnboarding
import SwiftUI


struct Welcome: View {
    @Environment(OnboardingNavigationPath.self)
    private var onboardingNavigationPath
    
//    @Environment(TestModule.self)
//    private var testModule: TestModule?
    
    var body: some View {
        let _ = Self._printChanges()
        OnboardingView(
            title: "My Heart Counts",
            subtitle: "\(unsafeBitCast(onboardingNavigationPath, to: uintptr_t.self))" as String,
//            subtitle: "WELCOME_SUBTITLE",
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
                onboardingNavigationPath.nextStep()
//                try await Task.sleep(for: .seconds(10))
            }
        )
        NavigationLink("NEXT", value: "\(TMPTestView.self)")
//        NavigationLink("NEXT") {
//            TMPTestView()
//        }
    }
}


#if DEBUG
#Preview {
    OnboardingStack {
        Welcome()
    }
}
#endif
