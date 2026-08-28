//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziFoundation
import SwiftData


// MARK: Staging

extension ManagedFileUpload {
    /// Takes ownership of the file at `url` and schedules it for upload.
    ///
    /// The file will be uploaded to `users/{accountId}/{category.firebasePath}/{url.lastPathComponent}` in the Firebase
    /// Storage — the remote object name is always exactly the caller's `lastPathComponent`, which callers such as the
    /// SensorKit uploader rely on when they record a reference to the file before it has been uploaded.
    ///
    /// This function returns once the upload has been durably scheduled; the upload itself happens asynchronously,
    /// and, if it cannot be completed during the current launch of the app, will be retried on subsequent launches.
    ///
    /// - parameter accountDataGeneration: the generation the caller staged this data under; defaults to the current one.
    ///     Passing the value the caller captured when it started collecting closes the window where data collected for
    ///     one account is staged after the app has moved on to another.
    @concurrent
    func stage(
        _ url: URL,
        category: Category,
        accountDataGeneration: Int? = nil,
        metadata: [String: String] = [:]
    ) async throws {
        let generation = accountDataGeneration ?? LocalPreferencesStore.standard[.accountDataGeneration]
        try ensureUploadsAreAllowed(generation)
        guard let accountId = await currentAccountId(), !accountId.isEmpty else {
            throw UploadError.noAccount
        }
        let upload = try await commitUpload(
            filename: url.lastPathComponent,
            category: category,
            metadata: metadata,
            accountId: accountId,
            accountDataGeneration: generation
        )
        do {
            try fileManager.moveItem(at: url, to: stagingUrl(forUploadWithId: upload.id))
        } catch {
            await discardUpload(upload.persistentId, category: category)
            throw error
        }
        await finishStaging(upload.persistentId, category: category)
    }

    /// Creates and commits the ``ScheduledUpload`` entry for a new upload.
    ///
    /// Runs on the main actor and contains no suspension point, so the gate check and the `save()` cannot be
    /// interleaved with a clear (which is also main-actor bound). That is what makes the guarantee "no entry is ever
    /// committed after the app decided the account's data must go" hold, rather than merely usually hold.
    private func commitUpload(
        filename: String,
        category: Category,
        metadata: [String: String],
        accountId: String,
        accountDataGeneration: Int
    ) throws -> (id: UUID, persistentId: PersistentIdentifier) {
        try ensureUploadsAreAllowed(accountDataGeneration)
        guard let modelContext else {
            throw UploadError.databaseUnavailable
        }
        register(category)
        let upload = ScheduledUpload(
            category: category,
            filename: filename,
            metadata: metadata,
            accountId: accountId,
            accountDataGeneration: accountDataGeneration
        )
        modelContext.insert(upload)
        try modelContext.save()
        return (upload.id, upload.persistentModelID)
    }

    /// Queues a freshly staged upload, if the queue is still open.
    ///
    /// - Important: deliberately does *not* check for cancellation, and never deletes the file. The file is already
    ///     in the module's custody at this point; throwing it away because a background task expired would be a data
    ///     loss path that neither the old file-system-based module nor its callers have any way to recover from
    ///     (the HealthKit anchor has already advanced by then). If the queue is closed, the entry simply stays
    ///     pending and is picked up by the next ``resumePendingUploads()``.
    private func finishStaging(_ uploadId: PersistentIdentifier, category: Category) {
        enqueue(uploadId, category: category)
    }

    /// Deletes a ``ScheduledUpload`` entry again, in response to its file failing to get moved into the staging directory.
    private func discardUpload(_ uploadId: PersistentIdentifier, category: Category) {
        guard let modelContext, let upload: ScheduledUpload = modelContext.existingModel(for: uploadId) else {
            return
        }
        modelContext.delete(upload)
        try? modelContext.save()
    }

    /// Whether an upload staged under `accountDataGeneration` may still be committed.
    nonisolated func uploadsAreAllowed(_ accountDataGeneration: Int) -> Bool {
        // Generation before flag: the writers set the flag first and bump the generation second, so a reader that
        // sees the new generation is guaranteed to also see the flag.
        let preferences = LocalPreferencesStore.standard
        return preferences[.accountDataGeneration] == accountDataGeneration && !configuration.isCleanupPending()
    }

    nonisolated func ensureUploadsAreAllowed(_ accountDataGeneration: Int) throws {
        try Swift::Task.checkCancellation()
        guard uploadsAreAllowed(accountDataGeneration) else {
            throw UploadError.cancelled
        }
    }
}


// MARK: Clearing

extension ManagedFileUpload {
    /// Deletes all pending uploads, incl. their staged files.
    ///
    /// Idempotent, and safe to call when there is nothing to clear or no database at all: a failure here leaves
    /// `pendingAccountDataCleanupRequired` set, which disables *all* data collection and uploading, so "there was
    /// nothing to do" must never be reported as a failure.
    func clearPendingUploads() async throws {
        await cancelAndWaitForQuiescence()
        defer {
            // Unconditionally reopen, even if something below throws: a closed queue would silently reject every
            // subsequent `stage()` for the rest of the launch.
            acceptsUploads = true
            Self.ensureDirectoriesExist(for: configuration, using: fileManager)
        }
        if let modelContext {
            try modelContext.delete(model: ScheduledUpload.self)
            try modelContext.save()
        }
        resetAllProgress()
        enqueuedUploads.removeAll()
        try removeContents(of: stagingDirectory)
        // Also sweep any legacy per-category directories: the migration deliberately leaves behind directories
        // belonging to categories that aren't registered during this launch, and those hold the previous account's
        // data just as much as the staging directory does.
        for url in (try? fileManager.contentsOfDirectory(at: configuration.directory, includingPropertiesForKeys: nil)) ?? []
        where url.lastPathComponent != stagingDirectory.lastPathComponent {
            try fileManager.removeItem(at: url)
        }
    }

    /// Deletes all pending uploads within the specified category, incl. their staged files.
    func clearPendingUploads(for category: Category) async throws {
        await cancelAndWaitForQuiescence()
        defer {
            acceptsUploads = true
            Self.ensureDirectoriesExist(for: configuration, using: fileManager)
        }
        guard let modelContext else {
            return
        }
        let categoryId = category.id
        let uploads = try modelContext.fetch(FetchDescriptor<ScheduledUpload>(predicate: #Predicate { $0.categoryId == categoryId }))
        for upload in uploads {
            let url = stagingUrl(forUploadWithId: upload.id)
            if fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
                try fileManager.removeItem(at: url)
            }
            enqueuedUploads.removeValue(forKey: upload.persistentModelID)
            modelContext.delete(upload)
        }
        try modelContext.save()
        resetProgress(for: category)
        let legacyDirectory = configuration.directory.appending(component: category.id, directoryHint: .isDirectory)
        if fileManager.isDirectory(at: legacyDirectory) {
            try fileManager.removeItem(at: legacyDirectory)
        }
    }

    /// Empties a directory entry-by-entry, rather than removing and recreating the directory itself.
    ///
    /// `removeItem` on a non-empty directory can race a concurrent writer and fail with `ENOTEMPTY` — which iOS 26
    /// reports as a misleading "you don't have permission" error, *after* it has already deleted part of the contents.
    /// Removing the entries individually keeps a partial failure partial, and keeps the directory itself in place so
    /// that subsequent staging still works.
    private func removeContents(of directory: URL) throws {
        guard fileManager.isDirectory(at: directory) else {
            return
        }
        var firstError: (any Error)?
        for url in (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError {
            throw firstError
        }
    }
}
