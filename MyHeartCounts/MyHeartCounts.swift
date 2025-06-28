//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import Spezi
import SwiftUI


// intentionally a global variable
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
            .environment(StudyBundleLoader.shared)
        }
        .environment(appDelegate)
    }
}
