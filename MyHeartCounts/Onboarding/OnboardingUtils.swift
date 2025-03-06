//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import SpeziOnboarding
import SwiftUI


private struct WithOnboardingStackWrapper<Body: View>: View {
    @Environment(OnboardingNavigationPath.self) private var path
    
    let makeContent: @MainActor (OnboardingNavigationPath) -> Body
    
    var body: Body {
        makeContent(path)
    }
}

func withOnboardingStackPath<Body: View>(@ViewBuilder _ makeContent: @MainActor @escaping (OnboardingNavigationPath) -> Body) -> some View {
    WithOnboardingStackWrapper<Body>(makeContent: makeContent)
}
