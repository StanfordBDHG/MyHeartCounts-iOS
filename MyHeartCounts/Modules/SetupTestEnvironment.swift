//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SpeziAccount
import SpeziFirebaseAccount
import SpeziHealthKit
import SpeziStudy
import struct SpeziViews.AnyLocalizedError


/// Sets up a test environment, by logging into a test account and enrolling in the current study definition.
@Observable
@MainActor
final class SetupTestEnvironment: Module, EnvironmentAccessible, Sendable {
    enum Config: LaunchOptionDecodable, Hashable {
        /// The app should not set up a test environment upon launching
        case no // swiftlint:disable:this identifier_name
        /// The app should set up a test environment, and optionally should clear any existing data.
        case yes(resetExistingData: Bool)
        
        init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
            try context.assertNumRawArgs(.atMost(1))
            switch context.rawArgs.first {
            case nil:
                // if the option (/flag) exists but has no value,
                // we implicitly set it to true (to indicate its presence)
                self = .yes(resetExistingData: true)
            case "keepExistingData":
                self = .yes(resetExistingData: false)
            case .some(let rawValue):
                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: rawValue)
            }
        }
    }
    
    enum State {
        /// The test environment hasn't been set up, and will not be set up.
        case disabled
        /// The test environment will soon be set up.
        case pending
        /// The test environment is currently being set up
        case settingUp
        /// The test environment has been set up
        case done
        /// There was an error setting up the test environment
        case failure(any Error)
    }
    
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(FirebaseAccountService.self) private var accountService: FirebaseAccountService?
    @ObservationIgnored @Dependency(StudyBundleLoader.self) private var studyBundleLoader
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(StudyManager.self) private var studyManager: StudyManager?
    // swiftlint:enable attributes
    
    @ObservationIgnored private let config: Config = LaunchOptions.launchOptions[.setupTestAccount]
    @MainActor private(set) var isInSetup = false
    
    /// Whether the test environment setup, in general, is enabled.
    ///
    /// - Note: This value being `true` or `false` does not mean that the test environment is currently enabled or disabled.
    ///     It just signals whether this module has/will set up a test environment.
    var isEnabled: Bool {
        config != .no
    }
    
    private(set) var state: State
    
    init() {
        state = if FeatureFlags.useFirebaseEmulator && FeatureFlags.skipOnboarding && config != .no {
            .pending
        } else {
            .disabled
        }
    }
    
    func configure() {
        switch state {
        case .pending:
            Task { @MainActor in
                self.state = .settingUp
                if !Spezi.didLoadFirebase {
                    Spezi.loadFirebase(for: .unitedStates)
                    try? await _Concurrency.Task.sleep(for: .seconds(4))
                }
                do {
                    try await setUp()
                    logger.notice("Successfully set up test environment")
                    self.state = .done
                } catch {
                    logger.error("ERROR SETTING UP TEST ENVIRONMENT: \(error)")
                    self.state = .failure(AnyLocalizedError(error: error, defaultErrorDescription: "\(error)"))
                }
            }
        default:
            break
        }
    }
    
    private func setUp() async throws {
        isInSetup = true
        defer {
            isInSetup = false
        }
        switch config {
        case .no:
            return
        case .yes(let resetExistingData):
            try await setUp(resetExistingData: resetExistingData)
        }
    }
    
    
    private func setUp(resetExistingData: Bool) async throws {
        logger.notice("Setting up Test Environment")
        guard let accountService else {
            logger.error("Unable to set up test account: no account service")
            return
        }
        guard let studyManager else {
            logger.error("Unable to set up test account: no StudyManager")
            return
        }
        if resetExistingData {
            for enrollment in studyManager.studyEnrollments {
                try studyManager.unenroll(from: enrollment)
            }
            do {
                try await accountService.logout()
            } catch FirebaseAccountError.notSignedIn {
                // ok
            }
        }
        do {
            try await accountService.login(userId: "lelandstanford@stanford.edu", password: "StanfordRocks!")
        } catch FirebaseAccountError.invalidCredentials {
            // account doesn't exist yet, signup
            var details = AccountDetails()
            details.userId = "lelandstanford@stanford.edu"
            details.password = "StanfordRocks!"
            details.name = PersonNameComponents(givenName: "Leland", familyName: "Stanford")
            details.genderIdentity = .male
            do {
                try await accountService.signUp(with: details)
            } catch {
                logger.error("Failed to setup test account: \(error)")
                throw error
            }
        } catch {
            // an error occurred logging in to the test account, and it's not because the account doesn't exist.
            throw error
        }
        let studyBundle = try await studyBundleLoader.update()
        logger.notice("Enrolling test environment into study bundle")
        let accessReqs = MyHeartCountsStandard.baselineHealthAccessReqs
            .merging(with: .init(read: studyBundle.studyDefinition.allCollectedHealthData))
        try await healthKit.askForAuthorization(for: accessReqs)
        try await studyManager.enroll(in: studyBundle)
    }
}
