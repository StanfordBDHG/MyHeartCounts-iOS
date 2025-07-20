//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziAccount
import SpeziFirebaseAccount
import SpeziStudy


/// Sets up a test environment, by logging into a test account and enrolling in the current study definition.
@MainActor
final class SetupTestEnvironment: Module, EnvironmentAccessible, Sendable {
    // swiftlint:disable attributes
    @Application(\.logger) private var logger
    @Dependency(Account.self) private var account: Account? // optional, as Firebase might be disabled
    @Dependency(FirebaseAccountService.self) private var accountService: FirebaseAccountService?
    @Dependency(StudyBundleLoader.self) private var studyBundleLoader
    @Dependency(StudyManager.self) private var studyManager: StudyManager?
    // swiftlint:enable attributes
    
    @MainActor private(set) var isInSetup = false
    
    nonisolated init() {}
    
    func setup() async throws {
        isInSetup = true
        defer {
            isInSetup = false
        }
        logger.notice("Setting up Test Environment")
        guard let accountService else {
            logger.error("Unable to set up test account: no account service")
            return
        }
        guard let studyManager else {
            logger.error("Unable to set up test account: no StudyManager")
            return
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
        try await studyManager.enroll(in: studyBundle)
    }
}
