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
    static let skipOnboarding = CommandLine.arguments.contains("--skipOnboarding")
    
    /// Always show the onboarding when the application is launched. Makes it easy to modify and test the onboarding flow without the need to manually remove the application or reset the simulator.
    static let showOnboarding = CommandLine.arguments.contains("--showOnboarding")
    
    /// Disables the Firebase interactions, including the login/sign-up step and the Firebase Firestore upload.
    static let disableFirebase = !useFirebaseEmulator && CommandLine.arguments.contains("--disableFirebase")
    
    /// Defines if the application should connect to the local firebase emulator.
    ///
    /// Always `true` in test builds.
    /// Specifying this flag implicitly also sets the ``disableFirebase`` to `false`.
    static let useFirebaseEmulator = ProcessInfo.isTestBuild || setupTestAccount || CommandLine.arguments.contains("--useFirebaseEmulator")
    
    /// Automatically sign in into a test account upon app launch.
    ///
    /// Specifying this flag implicitly also sets the ``useFirebaseEmulator`` flag to `true`.
    static let setupTestAccount = CommandLine.arguments.contains("--setupTestAccount")
    
    /// Whether, when running on a real device, we should load a special, different Firebase config instead of the one that would regularly get loaded.
    ///
    /// If this flag is present, the ``DeferredConfigLoading`` module will unconditionally attempt to load
    /// the Firebase configuration file called `GoogleService-Info-Override.plist` stored in the main bundle.
    static let overrideFirebaseConfigOnDevice = CommandLine.arguments.contains("--overrideFirebaseConfigOnDevice")
}
