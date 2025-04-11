//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziFirebaseAccount
import class SpeziOnboarding.OnboardingNavigationPath
import SpeziViews
import SwiftUI
import class ModelsR4.QuestionnaireResponse
import OSLog


let logger = Logger(subsystem: "edu.stanford.MyHeartCounts", category: "")


@main
struct MyHeartCounts: App {
    @UIApplicationDelegateAdaptor(MyHeartCountsDelegate.self)
    private var appDelegate
    
    @LocalPreference(.onboardingFlowComplete)
    private var didCompleteOnboarding
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .spezi(appDelegate)
            OnboardingSheet(
                didCompleteOnboarding: $didCompleteOnboarding
            )
        }
        .environment(appDelegate)
    }
}
