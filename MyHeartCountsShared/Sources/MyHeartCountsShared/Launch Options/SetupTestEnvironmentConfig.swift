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


extension SetupTestEnvironmentConfig: LaunchOptionDecodable, LaunchOptionEncodable {
    public static let cliFlagName = "--setupTestEnvironment"
    public static let resetOptionName = "reset"
    public static let loginAndEnrollOptionName = "login-and-enroll"
    
    public init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
        try context.assertNumRawArgs(.atMost(2))
        let allowedOptions: Set = [Self.resetOptionName, Self.loginAndEnrollOptionName]
        if case let invalidOptions = context.rawArgs.filter({ !allowedOptions.contains($0) }), !invalidOptions.isEmpty {
            throw LaunchOptionDecodingError.other("Invalid input: \(invalidOptions). Expected \(allowedOptions)")
        }
        self.init(
            resetExistingData: context.rawArgs.contains(Self.resetOptionName),
            loginAndEnroll: context.rawArgs.contains(Self.loginAndEnrollOptionName)
        )
    }
    
    public func launchOptionArgs(for launchOption: LaunchOption<Self>) -> [String] {
        guard self != .disabled else {
            return []
        }
        return Array {
            launchOption.key
            if resetExistingData {
                Self.resetOptionName
            }
            if loginAndEnroll {
                Self.loginAndEnrollOptionName
            }
        }
    }
}


extension LaunchOptions {
    /// Configures a test environment in the app upon launch.
    ///
    /// - Note: When this option is specified and either of the two
    public static let setupTestEnvironment = LaunchOption<SetupTestEnvironmentConfig>(
        SetupTestEnvironmentConfig.cliFlagName,
        default: .init(resetExistingData: false, loginAndEnroll: false)
    )
}

