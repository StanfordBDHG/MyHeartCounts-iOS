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


public final class FirebaseConfiguration: Module, DefaultInitializable, @unchecked Sendable {
    enum ConfigurationError: Error {
        case userNotAuthenticatedYet
    }

    public static var userCollection: CollectionReference {
        Firestore.firestore().collection("users")
    }


    @MainActor public var userDocumentReference: DocumentReference {
        get throws {
            guard let details = account?.details else {
                throw ConfigurationError.userNotAuthenticatedYet
            }
            return userDocumentReference(for: details.accountId)
        }
    }

    @MainActor public var userBucketReference: StorageReference {
        get throws {
            guard let details = account?.details else {
                throw ConfigurationError.userNotAuthenticatedYet
            }
            return Storage.storage().reference().child("users/\(details.accountId)")
        }
    }
    
    private let setupTestAccount: Bool

    @Application(\.logger)
    private var logger

    @Dependency(Account.self)
    private var account: Account? // optional, as Firebase might be disabled
    @Dependency(FirebaseAccountService.self)
    private var accountService: FirebaseAccountService?

    public convenience init() {
        self.init(setupTestAccount: false)
    }
    
    public init(setupTestAccount: Bool) {
        self.setupTestAccount = setupTestAccount
    }

    func userDocumentReference(for accountId: String) -> DocumentReference {
        Self.userCollection.document(accountId)
    }


    public func configure() {
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
