//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import Spezi
import SpeziFoundation
import SwiftUI


// intentionally a global variable
let logger = Logger(subsystem: "edu.stanford.MyHeartCounts", category: "")


@main
struct MyHeartCounts: App {
    static let website: URL = "https://myheartcounts.stanford.edu"
    
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
    
    init() {
        // This needs to run before *any* Spezi-related code is executed,
        // i.e. before the AppDelegate's `willFinishLaunchingWithOptions`
        // method gets called. Hence why we put it in here.
        let prefs = LocalPreferencesStore.standard
        if FeatureFlags.showOnboarding {
            prefs[.onboardingFlowComplete] = false
            prefs[.lastUsedFirebaseConfig] = nil
        }
        if FeatureFlags.skipOnboarding {
            prefs[.onboardingFlowComplete] = true
        }
    }
}
