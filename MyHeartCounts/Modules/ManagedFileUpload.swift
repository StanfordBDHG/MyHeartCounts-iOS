//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_length

import FirebaseStorage
import Foundation
import OSLog
import Spezi
import SpeziAccount
import SpeziFoundation
import SwiftData
import UIKit


/// Uploads files into the current user's directory in the Firebase Storage.
///
/// Pending uploads are tracked in a small database, with one ``ScheduledUpload`` entry per file;
/// the files themselves are kept in a flat staging directory, named after their entry's ``ScheduledUpload/id``.
/// Uploads are persistent: if an upload cannot be completed during the current launch of the app
/// (e.g.: missing network connection, no logged-in user, app getting terminated), it will be retried on subsequent launches.
@Observable
@MainActor
final class ManagedFileUpload: ServiceModule, EnvironmentAccessible, Sendable {
    /// A pending upload, i.e. a file that has been handed to the module but hasn't been uploaded yet.
    @Model
    fileprivate final class ScheduledUpload {
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
        
        /// The number of times the app already initiated an upload for this file.
        var numAttempts = 0
        
        init(category: Category, filename: String, metadata: [String: String]) {
            self.categoryId = category.id
            self.categoryFirebasePath = category.firebasePath
            self.filename = filename
            self.metadata = metadata
        }
    }
    
    
    nonisolated private static let directory = URL.documentsDirectory.appending(component: "ManagedFileUploading", directoryHint: .isDirectory)
    nonisolated private static let stagingDirectory = directory.appending(component: "staging", directoryHint: .isDirectory)
    nonisolated private static let databaseDirectory = URL.applicationSupportDirectory.appending(
        component: "ManagedFileUpload",
        directoryHint: .isDirectory
    )
    
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(Account.self) private var account: Account?
    // swiftlint:enable attributes
    
    private let newUploads = AsyncStream.makeStream(of: PersistentIdentifier.self)
    /// The uploads that have already been picked up for processing during the current launch of the app.
    /// Used to guard against an upload getting processed twice, in case it somehow ends up in ``newUploads`` more than once.
    private var processedUploads: Set<PersistentIdentifier> = []
    
    private(set) var categories: Set<Category>
    nonisolated(unsafe) private let fileManager = FileManager()
    
    /// The database in which the module keeps track of its pending uploads.
    ///
    /// `nil` if the database couldn't be opened during the current launch (see ``init(categories:)``);
    /// in that case the module is inert until the next launch.
    nonisolated private let modelContainer: ModelContainer?
    private var modelContext: ModelContext? {
        modelContainer?.mainContext
    }
    /// Whether the database couldn't be opened and had to be moved aside and recreated during the current launch.
    private var databaseWasRecreated = false
    
    /// A `Progress` instance representing each category's upload progress,
    /// i.e. the progress of uploading the category's submitted files into the Firebase Storage.
    ///
    /// A category is present in here iff it currently has uploads that are scheduled or being processed during this launch;
    /// uploads that failed (and are waiting to be retried on a subsequent launch) get removed from the progress upon failing.
    @MainActor private(set) var progressByCategory: [Category: Progress] = [:]
    
    /// Creates a new instance of the `ManagedFileUpload` module.
    ///
    /// Even though it is allowed to schedule uploads for categories not specified when initially creating the module (via the `categories` parameter),
    /// it is strongly recommended that all expected categories be specified here.
    /// The reason for this is that the module will use this initial list of categories to migrate any pending uploads
    /// that were created by the old, file-system-based version of this module.
    ///
    /// - parameter categories: A list of well-known ``Category`` definitions.
    init(@ArrayBuilder<Category> categories: () -> [Category]) {
        self.categories = Set(categories())
        let fileManager = FileManager()
        try? fileManager.createDirectory(at: Self.databaseDirectory, withIntermediateDirectories: true)
        let schema = Schema([ScheduledUpload.self], version: Schema.Version(0, 0, 1))
        let config = ModelConfiguration(
            "ManagedFileUpload",
            schema: schema,
            url: Self.databaseDirectory.appending(component: "db.sqlite", directoryHint: .notDirectory)
        )
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            guard UIApplication.shared.isProtectedDataAvailable else {
                // The device hasn't been unlocked since its last reboot (e.g.: a background launch before first unlock),
                // in which case we simply cannot open the database. This is a transient condition (the database is fine,
                // we just can't access it right now) so we must NOT treat it as corruption.
                // The module stays inert for this launch; the next normal launch will pick the pending uploads back up.
                modelContainer = nil
                return
            }
            // The database exists but can't be opened; most likely it is corrupted or schema-incompatible.
            // Rather than fatalError-ing on every subsequent launch, we move it aside and start over with a fresh database.
            // (Moved aside, not deleted, so that the previously-pending uploads at least remain recoverable.)
            for filename in ["db.sqlite", "db.sqlite-shm", "db.sqlite-wal"] {
                let url = Self.databaseDirectory.appending(component: filename, directoryHint: .notDirectory)
                let brokenUrl = Self.databaseDirectory.appending(component: "broken-\(filename)", directoryHint: .notDirectory)
                try? fileManager.removeItem(at: brokenUrl)
                try? fileManager.moveItem(at: url, to: brokenUrl)
            }
            modelContainer = try? ModelContainer(for: schema, configurations: [config])
            databaseWasRecreated = true
        }
    }
    
    nonisolated private static func stagingUrl(forUploadWithId id: UUID) -> URL {
        stagingDirectory.appending(component: id.uuidString, directoryHint: .notDirectory)
    }
    
    func configure() {
        guard let modelContext else {
            logger.warning("Unable to open pending-uploads database; file uploading is disabled for this launch.")
            return
        }
        if databaseWasRecreated {
            logger.warning("The pending-uploads database was unreadable and has been moved aside; previously-pending uploads were dropped.")
        }
        do {
            try fileManager.createDirectory(at: Self.stagingDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Unable to create staging directory at \(Self.stagingDirectory)")
        }
        migrateLegacyFileBasedUploads()
        deleteOrphanedStagingFiles()
        // schedule everything that's still pending from previous launches (incl. any just-migrated entries).
        let descriptor = FetchDescriptor<ScheduledUpload>(sortBy: [SortDescriptor(\.creationDate)])
        for upload in (try? modelContext.fetch(descriptor)) ?? [] {
            addUploadToProgress(for: resolveCategory(id: upload.categoryId, firebasePath: upload.categoryFirebasePath))
            newUploads.continuation.yield(upload.persistentModelID)
        }
    }
    
    func run() async {
        await withManagedTaskQueue(limit: 5) { taskQueue in
            for await upload in self.newUploads.stream {
                taskQueue.addTask {
                    do {
                        try await self.doUpload(upload)
                    } catch {
                        await self.logger.error("Upload failed: \(error). Will retry on next launch.")
                    }
                }
            }
        }
    }
    
    func isActive(_ category: Category) -> Bool {
        progressByCategory[category] != nil
    }
}


// MARK: Migration & Cleanup

extension ManagedFileUpload {
    /// Migrates pending uploads that were created by the old, file-system-based version of this module into the database.
    ///
    /// The old module tracked its pending uploads as files in one directory per category (within `Self.directory`), stored under their remote filenames.
    /// We turn every such file into a ``ScheduledUpload`` entry and move it into the staging directory.
    /// This is a one-time migration in the sense that it moves the files out of the legacy directories as it processes them;
    /// on all subsequent launches there's simply nothing left to migrate.
    private func migrateLegacyFileBasedUploads() {
        guard let modelContext else {
            return
        }
        let pendingMoves: [(srcUrl: URL, upload: ScheduledUpload)] = categories.reduce(into: []) { result, category in
            // construct the URL exactly the way the old module did, so that we look for the files where it put them.
            let legacyDir = Self.directory.appending(component: category.id, directoryHint: .isDirectory)
            guard fileManager.isDirectory(at: legacyDir) else {
                return
            }
            for url in (try? fileManager.contents(of: legacyDir)) ?? [] where !fileManager.isDirectory(at: url) {
                let upload = ScheduledUpload(category: category, filename: url.lastPathComponent, metadata: [:])
                modelContext.insert(upload)
                result.append((url, upload))
            }
        }
        if !pendingMoves.isEmpty {
            do {
                // save all entries in a single commit, before moving any files: a database entry without a file resolves itself
                // (it simply gets discarded, and the still-in-place file gets re-migrated on the next launch),
                // whereas a moved file without an entry would be deleted by the orphan sweep.
                try modelContext.save()
            } catch {
                logger.error("Unable to migrate pending uploads: \(error)")
                modelContext.rollback()
                return
            }
            var anyMovesFailed = false
            for (srcUrl, upload) in pendingMoves {
                do {
                    try fileManager.moveItem(at: srcUrl, to: Self.stagingUrl(forUploadWithId: upload.id))
                } catch {
                    logger.error("Unable to migrate pending upload at \(srcUrl): \(error)")
                    modelContext.delete(upload)
                    anyMovesFailed = true
                }
            }
            if anyMovesFailed {
                try? modelContext.save()
            }
        }
        for category in categories {
            let legacyDir = Self.directory.appending(component: category.id, directoryHint: .isDirectory)
            if fileManager.isDirectory(at: legacyDir), (try? fileManager.contents(of: legacyDir))?.isEmpty == true {
                try? fileManager.removeItem(at: legacyDir)
            }
        }
        removeEmptyLegacyDirectories()
    }
    
    /// Removes any (now-empty) directories left behind by the old file-system-based version of the module.
    ///
    /// Directories that still contain files (i.e., pending uploads belonging to categories that aren't registered with the module)
    /// are intentionally left in place, so that the data can still be migrated in the future.
    private func removeEmptyLegacyDirectories() {
        let children = (try? fileManager.contents(of: Self.directory)) ?? []
        for url in children where fileManager.isDirectory(at: url) && url.lastPathComponent != Self.stagingDirectory.lastPathComponent {
            if directoryTreeContainsFiles(at: url) {
                logger.warning("Found unmigrated pending uploads at \(url.path); leaving them in place.")
            } else {
                try? fileManager.removeItem(at: url)
            }
        }
    }
    
    nonisolated private func directoryTreeContainsFiles(at url: URL) -> Bool {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return false
        }
        return enumerator.lazy
            .compactMap { $0 as? URL }
            .contains { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true }
    }
    
    /// Deletes any files in the staging directory that don't belong to a ``ScheduledUpload`` entry.
    ///
    /// Such files can come into existence when the app gets terminated after an upload's database entry was deleted, but before its file was.
    private func deleteOrphanedStagingFiles() {
        guard !databaseWasRecreated, let modelContext else {
            // if the database was just recreated, the files' entries may have been lost rather than legitimately deleted;
            // we leave the files in place (alongside the moved-aside database) instead of destroying them as well.
            return
        }
        guard let uploads = try? modelContext.fetch(FetchDescriptor<ScheduledUpload>()) else {
            // if we can't read the database, we can't tell which files are orphaned. leave everything in place.
            return
        }
        let validNames = Set(uploads.map { $0.id.uuidString })
        for url in (try? fileManager.contents(of: Self.stagingDirectory)) ?? [] where !validNames.contains(url.lastPathComponent) {
            logger.notice("Deleting orphaned staging file at \(url.path)")
            try? fileManager.removeItem(at: url)
        }
    }
}


// MARK: Clearing

extension ManagedFileUpload {
    /// Deletes all pending uploads, incl. their staged files.
    func clearPendingUploads() throws {
        if let modelContext {
            try modelContext.delete(model: ScheduledUpload.self)
            try modelContext.save()
        }
        progressByCategory.removeAll()
        try fileManager.removeItem(at: Self.directory)
        try fileManager.createDirectory(at: Self.stagingDirectory, withIntermediateDirectories: true)
    }
    
    /// Deletes all pending uploads within the specified category, incl. their staged files.
    func clearPendingUploads(for category: Category) throws {
        guard let modelContext else {
            return
        }
        let categoryId = category.id
        let uploads = try modelContext.fetch(FetchDescriptor<ScheduledUpload>(predicate: #Predicate { $0.categoryId == categoryId }))
        for upload in uploads {
            try? fileManager.removeItem(at: Self.stagingUrl(forUploadWithId: upload.id))
            modelContext.delete(upload)
        }
        try modelContext.save()
        progressByCategory[category] = nil
    }
    
    /// The total on-disk size, in bytes, of all files pending upload within the specified category.
    func totalPendingFileSize(for category: Category) -> Int64? {
        guard let modelContext else {
            return nil
        }
        let categoryId = category.id
        guard let uploads = try? modelContext.fetch(
            FetchDescriptor<ScheduledUpload>(predicate: #Predicate { $0.categoryId == categoryId })
        ) else {
            return nil
        }
        var total: Int64 = 0
        for upload in uploads {
            let url = Self.stagingUrl(forUploadWithId: upload.id)
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }
}


// MARK: Categories

extension ManagedFileUpload {
    struct Category: Identifiable, Hashable, Sendable {
        let id: String
        let firebasePath: String
        let title: LocalizedStringResource
        
        /// Creates a new Category
        ///
        /// - parameter id: Unique identifier for this category.
        /// - parameter title: User-visible title to be used with uploads in this category
        /// - parameter firebasePath: The folder, relative to the user's directory in the storage bucket, where files uploaded for this category should be stored.
        init(id: String, title: LocalizedStringResource, firebasePath: String) {
            self.id = id
            self.title = title
            self.firebasePath = firebasePath
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    /// Resolves a ``ScheduledUpload``'s category information into a ``Category``,
    /// preferring the matching currently-registered category, if it exists.
    private func resolveCategory(id: String, firebasePath: String) -> Category {
        categories.first { $0.id == id } ?? Category(id: id, title: "\(id)", firebasePath: firebasePath)
    }
}


// MARK: Uploading

extension ManagedFileUpload {
    private enum UploadError: Error {
        case databaseUnavailable
        case noAccount
        case uploadFailed(any Error)
    }
    
    /// Schedules the file at `url` for upload, taking ownership of the file by moving it into the module's staging directory.
    ///
    /// The file will be uploaded to `users/{accountId}/{category.firebasePath}/{url.lastPathComponent}` in the Firebase Storage.
    /// This function returns once the upload has been durably scheduled; the upload itself happens asynchronously,
    /// and, if it cannot be completed during the current launch of the app, will be retried on subsequent launches.
    @concurrent
    func scheduleForUpload(_ url: URL, category: Category, metadata: [String: String] = [:]) async throws {
        let (uploadId, persistentId) = try await registerUpload(filename: url.lastPathComponent, category: category, metadata: metadata)
        do {
            try fileManager.moveItem(at: url, to: Self.stagingUrl(forUploadWithId: uploadId))
        } catch {
            await discardUpload(persistentId)
            throw error
        }
        newUploads.continuation.yield(persistentId)
    }
    
    /// Creates and saves a ``ScheduledUpload`` entry for a new upload, and counts it into its category's progress.
    private func registerUpload(filename: String, category: Category, metadata: [String: String]) throws -> (UUID, PersistentIdentifier) {
        guard let modelContext else {
            throw UploadError.databaseUnavailable
        }
        categories.insert(category)
        let upload = ScheduledUpload(category: category, filename: filename, metadata: metadata)
        modelContext.insert(upload)
        try modelContext.save()
        addUploadToProgress(for: category)
        return (upload.id, upload.persistentModelID)
    }
    
    /// Deletes a ``ScheduledUpload`` entry again, in response to its file failing to get moved into the staging directory.
    private func discardUpload(_ id: PersistentIdentifier) {
        guard let modelContext, let upload: ScheduledUpload = modelContext.existingModel(for: id) else {
            return
        }
        abortUploadProgress(for: resolveCategory(id: upload.categoryId, firebasePath: upload.categoryFirebasePath))
        modelContext.delete(upload)
        try? modelContext.save()
    }
    
    /// Marks the upload as picked-up for processing.
    ///
    /// - returns: `true` if the caller should proceed with the upload; `false` if it was already picked up previously during this launch.
    private func claimUpload(_ id: PersistentIdentifier) -> Bool {
        processedUploads.insert(id).inserted
    }
    
    @concurrent
    private func doUpload(_ uploadId: PersistentIdentifier) async throws(UploadError) {
        guard await claimUpload(uploadId), let modelContainer else {
            return
        }
        let context = ModelContext(modelContainer)
        guard let upload: ScheduledUpload = context.existingModel(for: uploadId) else {
            // the upload got cleared inbetween getting scheduled and us getting to process it;
            // its progress entry was reset by the clear operation.
            return
        }
        let category = await resolveCategory(id: upload.categoryId, firebasePath: upload.categoryFirebasePath)
        let fileUrl = Self.stagingUrl(forUploadWithId: upload.id)
        guard fileManager.itemExists(at: fileUrl) else {
            await logger.error("Discarding scheduled upload \(upload.id): its staged file is missing.")
            context.delete(upload)
            try? context.save()
            await abortUploadProgress(for: category)
            return
        }
        guard let accountId = await account?.details?.accountId else {
            await abortUploadProgress(for: category)
            throw .noAccount
        }
        let storageRef = Storage.storage().reference(withPath: "users/\(accountId)/\(category.firebasePath)/\(upload.filename)")
        await logger.notice("uploading to \(storageRef.bucket):\(storageRef.fullPath)")
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        if !upload.metadata.isEmpty {
            metadata.customMetadata = upload.metadata
        }
        upload.numAttempts += 1
        try? context.save()
        do {
            _ = try await storageRef.putFileAsync(from: fileUrl, metadata: metadata)
        } catch {
            await logger.error("Upload to \(storageRef.fullPath) failed: \(error)")
            await abortUploadProgress(for: category)
            throw .uploadFailed(error)
        }
        context.delete(upload)
        try? context.save()
        do {
            try fileManager.removeItem(at: fileUrl)
        } catch {
            // not a problem: the file is orphaned now that its entry is gone, and will get cleaned up on the next launch.
            await logger.error("Unable to delete uploaded file at \(fileUrl): \(error)")
        }
        await completeUploadProgress(for: category)
    }
}


// MARK: Progress Tracking

extension ManagedFileUpload {
    /// Counts a newly-scheduled (or newly-resumed) upload into its category's progress.
    ///
    /// This happens when the upload is enqueued (rather than when it starts getting processed),
    /// so that the progress' total reflects the full queue depth instead of just the currently-in-flight uploads.
    private func addUploadToProgress(for category: Category) {
        if let progress = progressByCategory[category] {
            progress.totalUnitCount += 1
        } else {
            let progress = Progress(totalUnitCount: 1)
            progress.localizedDescription = String(localized: category.title)
            progressByCategory[category] = progress
        }
    }
    
    private func completeUploadProgress(for category: Category) {
        guard let progress = progressByCategory[category] else {
            return
        }
        progress.completedUnitCount += 1
        if progress.completedUnitCount >= progress.totalUnitCount {
            progressByCategory[category] = nil
        }
    }
    
    /// Un-counts a failed or discarded upload from its category's progress, so that the category doesn't appear active forever.
    private func abortUploadProgress(for category: Category) {
        guard let progress = progressByCategory[category] else {
            return
        }
        progress.totalUnitCount -= 1
        if progress.totalUnitCount <= 0 || progress.completedUnitCount >= progress.totalUnitCount {
            progressByCategory[category] = nil
        }
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
