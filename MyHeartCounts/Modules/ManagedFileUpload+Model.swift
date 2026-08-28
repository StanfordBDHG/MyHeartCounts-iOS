//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData


extension ManagedFileUpload {
    /// The current version of the ``ScheduledUpload`` schema.
    enum SchemaV1: VersionedSchema {
        nonisolated static var versionIdentifier: Schema.Version {
            Schema.Version(1, 0, 0)
        }

        nonisolated static var models: [any PersistentModel.Type] {
            [ManagedFileUpload.ScheduledUpload.self]
        }
    }

    /// Migration plan for the pending-uploads store.
    ///
    /// Every future column addition becomes one additional ``VersionedSchema`` plus a `MigrationStage.lightweight`
    /// entry here; without a plan, ordinary schema evolution would instead surface as a failure to open the store and
    /// route through the corruption handling in ``makeModelContainer(for:)``, silently dropping the queue.
    enum MigrationPlan: SchemaMigrationPlan {
        nonisolated static var schemas: [any VersionedSchema.Type] {
            [SchemaV1.self]
        }

        nonisolated static var stages: [MigrationStage] {
            []
        }
    }

    /// A pending upload, i.e. a file that has been handed to the module but hasn't been uploaded yet.
    @Model
    final class ScheduledUpload {
        @Attribute(.unique)
        private(set) var id = UUID()

        /// The id of the ``ManagedFileUpload/Category`` within which the file should be uploaded.
        private(set) var categoryId: String
        /// The category's remote folder, denormalized into the entry so that the upload can still be
        /// performed if the category isn't registered with the module anymore.
        private(set) var categoryFirebasePath: String
        /// The name under which the file should be uploaded, within the category's remote folder.
        private(set) var filename: String
        /// Custom metadata that should be associated with the file, via the firebase storage metadata API.
        private(set) var metadata: [String: String]
        /// When the upload was scheduled.
        private(set) var creationDate = Date()

        /// The id of the account this file was collected for, and into whose storage directory it must be uploaded.
        ///
        /// Captured when the upload is staged, rather than read at upload time: an upload that outlives a logout
        /// must never end up in the next participant's directory.
        /// `nil` only for entries created by the one-time migration from the old, file-system-based module,
        /// which runs before firebase has restored the session and therefore cannot know the account.
        var accountId: String?
        /// The value of `LocalPreferenceKeys.accountDataGeneration` at the time the upload was staged.
        ///
        /// Recorded for diagnostics; uploads are not gated on it (``accountId`` answers the question that matters,
        /// and a log-out-then-log-in as the same user bumps the generation without changing the owner).
        var accountDataGeneration: Int = 0

        /// The number of times the app already initiated an upload for this file.
        var numAttempts = 0

        init(
            category: Category,
            filename: String,
            metadata: [String: String],
            accountId: String?,
            accountDataGeneration: Int
        ) {
            self.categoryId = category.id
            self.categoryFirebasePath = category.firebasePath
            self.filename = filename
            self.metadata = metadata
            self.accountId = accountId
            self.accountDataGeneration = accountDataGeneration
        }
    }


    /// A ``ScheduledUpload`` snapshot that can be handed across isolation domains.
    ///
    /// SwiftData models are bound to the context that fetched them; the queue only ever needs the identifier
    /// and the category information, so we copy those out instead of keeping the model objects alive.
    struct PendingUpload: Sendable, Hashable {
        let persistentId: PersistentIdentifier
        let categoryId: String
        let categoryFirebasePath: String
    }
}


extension ModelContext {
    func existingModel<T: PersistentModel>(for id: PersistentIdentifier) -> T? {
        if let model: T = self.registeredModel(for: id) {
            return model
        }
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.persistentModelID == id }
        )
        return (try? self.fetch(descriptor))?.first
    }
}
