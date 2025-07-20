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
import SpeziStudy


final class FirebaseConfiguration: Module, EnvironmentAccessible, @unchecked Sendable {
    enum ConfigurationError: Error {
        case userNotAuthenticatedYet
    }

    // swiftlint:disable attributes
    @Application(\.logger) private var logger
    @Dependency(Account.self) private var account: Account? // optional, as Firebase might be disabled
    @Dependency(FirebaseAccountService.self) private var accountService: FirebaseAccountService?
    // swiftlint:enable attributes
    
    init() {}
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
