//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

private import SpeziFoundation


public struct SetupTestEnvironmentConfig: Hashable, Sendable {
    public static let disabled = Self(resetExistingData: false, loginAndEnroll: false)
    
    /// Whether the app should reset all data on launch.
    ///
    /// This option will:
    /// - log out the current user
    /// - unenroll from the study
    /// - delete all cached study bundles
    /// - delete all pending uploads
    /// - reset the bulk health upload state
    /// - reset the SensorKit anchors
    /// - delete the entire `LocalStorage`
    public let resetExistingData: Bool
    
    /// Whether the app should log in to a test user.
    ///
    /// Specifying only this option but not also the previous one will simply ensure that the app has a logged-in user which is enrolled into the study.
    /// You can combine this option with the previous one to also ensure that the app is in a clean state.
    ///
    /// - Note: Setting this value to `false` does not mean that an existing user will be logged out.
    public let loginAndEnroll: Bool
    
    public init(resetExistingData: Bool, loginAndEnroll: Bool) {
        self.resetExistingData = resetExistingData
        self.loginAndEnroll = loginAndEnroll
    }
}


extension SetupTestEnvironmentConfig {
    public static let cliFlagName = "--setupTestEnvironment"
    public static let resetOptionName = "reset"
    public static let loginAndEnrollOptionName = "login-and-enroll"
    
    public var launchOptionRepresentation: [String] {
        guard self != .disabled else {
            return []
        }
        return Array {
            Self.cliFlagName
            if resetExistingData {
                Self.resetOptionName
            }
            if loginAndEnroll {
                Self.loginAndEnrollOptionName
            }
        }
    }
}
