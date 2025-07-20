//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A collection of feature flags for the My Heart Counts.
enum FeatureFlags {
    /// Skips the onboarding flow to enable easier development of features in the application and to allow UI tests to skip the onboarding flow.
    static var skipOnboarding: Bool {
        LaunchOptions.launchOptions[.skipOnboarding]
    }
    
    /// Always show the onboarding when the application is launched. Makes it easy to modify and test the onboarding flow without the need to manually remove the application or reset the simulator.
    static var showOnboarding: Bool {
        LaunchOptions.launchOptions[.showOnboarding]
    }
    
    /// Disables the Firebase interactions, including the login/sign-up step and the Firebase Firestore upload.
    ///
    /// - Note: This takes precedence over all other firebase-related flags. I.e., if you
    static var disableFirebase: Bool {
        LaunchOptions.launchOptions[.disableFirebase]
    }
    
    /// Defines if the application should connect to the local firebase emulator.
    ///
    /// Always `true` in test builds.
    /// Specifying this flag implicitly also sets the ``disableFirebase`` to `false`.
    static var useFirebaseEmulator: Bool {
        ProcessInfo.isTestBuild || setupTestAccount || LaunchOptions.launchOptions[.useFirebaseEmulator]
    }
    
    /// Automatically sign in into a test account upon app launch.
    ///
    /// Specifying this flag implicitly also sets the ``useFirebaseEmulator`` flag to `true`.
    static var setupTestAccount: Bool {
        LaunchOptions.launchOptions[.setupTestAccount]
    }
    
    /// Disables the automatic bulk export and upload of historical Health data
    static var disableAutomaticBulkHealthExport: Bool {
        LaunchOptions.launchOptions[.disableAutomaticBulkHealthExport]
    }
    
    /// Whether the should load a special, different Firebase config instead of the one that would regularly get loaded.
    ///
    /// If specified, the ``DeferredConfigLoading`` module will unconditionally attempt to load the override config.
    static var overrideFirebaseConfig: DeferredConfigLoading.FirebaseConfigSelector? {
        LaunchOptions.launchOptions[.overrideFirebaseConfig]
    }
}


extension ProcessInfo {
    static var isBeingUITested: Bool {
        ProcessInfo.processInfo.environment["MHC_IS_BEING_UI_TESTED"] == "1"
    }
}


extension LaunchOptions {
    static let skipOnboarding = LaunchOption<Bool>("--skipOnboarding", default: false)
    static let showOnboarding = LaunchOption<Bool>("--showOnboarding", default: false)
    
    static let disableFirebase = LaunchOption<Bool>("--disableFirebase", default: false)
    static let useFirebaseEmulator = LaunchOption<Bool>("--useFirebaseEmulator", default: false)
    static let setupTestAccount = LaunchOption<Bool>("--setupTestAccount", default: false)
    static let overrideFirebaseConfig = LaunchOption<DeferredConfigLoading.FirebaseConfigSelector?>("--overrideFirebaseConfig", default: nil)
    
    static let disableAutomaticBulkHealthExport = LaunchOption<Bool>("--disableAutomaticBulkHealthExport", default: false)
    
    static let overrideStudyBundleLocation = LaunchOption<URL?>("--overrideStudyBundleLocation", default: nil)
}
