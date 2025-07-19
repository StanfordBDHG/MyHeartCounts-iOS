//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import FirebaseStorage
import Spezi
import SpeziAccount
import SpeziFirebaseAccount


final class FirebaseConfiguration: Module, @unchecked Sendable {
    enum ConfigurationError: Error {
        case userNotAuthenticatedYet
    }
    
    private let setupTestAccount: Bool

    @Application(\.logger)
    private var logger

    @Dependency(Account.self)
    private var account: Account? // optional, as Firebase might be disabled
    @Dependency(FirebaseAccountService.self)
    private var accountService: FirebaseAccountService?

    
    init(setupTestAccount: Bool = false) {
        self.setupTestAccount = setupTestAccount
    }


    func configure() {
        Task {
            await setupTestAccount()
        }
    }


    private func setupTestAccount() async {
        guard let accountService, setupTestAccount else {
            return
        }
        do {
            try await accountService.login(userId: "lelandstanford@stanford.edu", password: "StanfordRocks!")
            return
        } catch {
            guard let accountError = error as? FirebaseAccountError,
                  case .invalidCredentials = accountError else {
                logger.error("Failed to login into test account: \(error)")
                return
            }
        }
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
        }
    }
}


extension FirebaseConfiguration {
    static var usersCollection: CollectionReference {
        Firestore.firestore().collection("users")
    }
    
    @MainActor var userDocumentReference: DocumentReference {
        get throws {
            Self.usersCollection.document(try accountId)
        }
    }

    @MainActor var userBucketReference: StorageReference {
        get throws {
            Storage.storage().reference().child("users/\(try accountId)")
        }
    }
    
    var feedbackCollection: CollectionReference {
        Firestore.firestore().collection("feedback")
    }
    
    /// Retrieves the `accountId` of the currently logged-in user, or throws an error if there is no logged-in user.
    @MainActor var accountId: String {
        get throws(ConfigurationError) {
            guard let details = account?.details else {
                throw ConfigurationError.userNotAuthenticatedYet
            }
            return details.accountId
        }
    }
}
