//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


private struct MyHeartCountsAppTestingSetup: ViewModifier {
    @AppStorage(StorageKeys.onboardingFlowComplete)
    private var completedOnboardingFlow = false
    
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if FeatureFlags.skipOnboarding {
                    completedOnboardingFlow = true
                }
                if FeatureFlags.showOnboarding {
                    completedOnboardingFlow = false
                }
            }
    }
}


extension View {
    func testingSetup() -> some View {
        self.modifier(MyHeartCountsAppTestingSetup())
    }
}
