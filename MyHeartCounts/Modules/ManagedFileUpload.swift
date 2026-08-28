//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SpeziAccount
import SpeziFoundation
import SwiftData


/// Uploads files into the current user's directory in the Firebase Storage.
///
/// Pending uploads are tracked in a small database, with one ``ScheduledUpload`` entry per file;
/// the files themselves are kept in a flat staging directory, named after their entry's ``ScheduledUpload/id``.
/// Uploads are persistent: if an upload cannot be completed during the current launch of the app
/// (e.g.: missing network connection, no logged-in user, app getting terminated), it will be retried on subsequent launches.
///
/// - Note: this is intentionally a plain ``Spezi/Module`` rather than a `ServiceModule`: a `ServiceModule`'s `run()` is
///     only ever reached via `.task(spezi.run)` in Spezi's view modifier, which the app applies inside its `WindowGroup`.
///     A launch that connects no scene — a `BGTask` wake, or HealthKit background delivery — would therefore never start it,
///     i.e. exactly the situations this module exists to serve. `configure()` runs on every launch, so the drain starts there.
@Observable
@MainActor
final class ManagedFileUpload: Spezi::Module, EnvironmentAccessible, Sendable {
    /// Uploads a staged file on the module's behalf.
    ///
    /// `filename` is the name the file must be given remotely — always exactly the `lastPathComponent` the caller
    /// handed to ``stage(_:category:accountDataGeneration:metadata:)``, never the (uniquified) on-disk staging name.
    typealias UploadOperation = @Sendable (
        _ fileUrl: URL,
        _ category: Category,
        _ accountId: String,
        _ filename: String,
        _ metadata: [String: String]
    ) async throws -> Void

    /// Where the module keeps its state, how it talks to the outside world, and how much work it does at once.
    ///
    /// The defaults are what the app uses; the injection points exist so that the upload path — the one part of the
    /// app that handles participant data on its way off the device — can be tested without a Firebase environment.
    struct Configuration: Sendable {
        /// The directory holding the staged files (and any not-yet-migrated legacy per-category directories).
        var directory: URL = ManagedFileUpload.defaultDirectory
        /// The directory holding the pending-uploads database.
        ///
        /// Deliberately outside ``directory``, so that ``ManagedFileUpload/clearPendingUploads()`` cannot destroy
        /// the index it is iterating.
        var databaseDirectory: URL = ManagedFileUpload.defaultDatabaseDirectory
        /// Whether to keep the database in memory instead of on disk.
        var isStoredInMemoryOnly = false
        /// How many files may be uploaded concurrently.
        ///
        /// Each in-flight upload retains its request body, and the module always spends someone else's background
        /// execution budget, so this is kept deliberately small.
        var maximumConcurrentUploads = 2
        /// Resolves the currently signed-in account's id; `nil` to read it from the `Account` module.
        var accountIdProvider: (@Sendable () async -> String?)?
        /// Performs the actual upload; `nil` to upload into the Firebase Storage.
        var uploadOperation: UploadOperation?
        /// Whether data belonging to a previous account still needs to be cleared.
        var isCleanupPending: @Sendable () -> Bool = {
            LocalPreferencesStore.standard[.pendingAccountDataCleanupRequired]
        }
    }

    enum UploadError: Error, Sendable {
        case databaseUnavailable
        case noAccount
        case cancelled
    }

    /// The outcome of a single upload attempt, as seen by the queue's bookkeeping.
    enum UploadOutcome: Sendable {
        /// The file was uploaded and its entry removed.
        case completed
        /// The attempt failed; the entry survives and will be retried on a later resume or launch.
        case failed
        /// The entry is gone (already cleared, its file was missing, or it belongs to a different account).
        case discarded
    }

    nonisolated static let defaultDirectory = URL.documentsDirectory.appending(
        component: "ManagedFileUploading",
        directoryHint: .isDirectory
    )
    nonisolated static let defaultDatabaseDirectory = URL.applicationSupportDirectory.appending(
        component: "ManagedFileUpload",
        directoryHint: .isDirectory
    )

    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) var logger
    @ObservationIgnored @Dependency(Account.self) var account: Account?
    // swiftlint:enable attributes

    nonisolated let configuration: Configuration
    nonisolated(unsafe) let fileManager = FileManager()

    let newUploads = AsyncStream.makeStream(of: PersistentIdentifier.self)
    /// Whether the queue currently accepts new work.
    ///
    /// Set to `false` by ``cancelAndWaitForQuiescence()`` and back to `true` as the unconditional first step of
    /// ``resumePendingUploads()``, so that a failed or early-returning resume can never leave the queue closed.
    var acceptsUploads = true
    /// Uploads that have been handed to the queue and haven't finished yet, and the category each was counted into.
    ///
    /// Entries are removed again when the upload finishes, in any way — unlike a plain "already seen" set, a
    /// failed upload therefore stays eligible for a later retry instead of being blacklisted for the launch.
    var enqueuedUploads: [PersistentIdentifier: Category] = [:]
    /// The currently in-flight uploads, so that they can be cancelled and awaited.
    var activeUploads: [PersistentIdentifier: Swift::Task<UploadOutcome, Never>] = [:]
    var quiescenceWaiters: [CheckedContinuation<Void, Never>] = []
    var drainTask: Swift::Task<Void, Never>?

    private(set) var categories: Set<Category>

    /// The database in which the module keeps track of its pending uploads.
    ///
    /// `nil` if the database couldn't be opened during the current launch (see ``makeModelContainer(for:)``);
    /// in that case the module is inert until the next launch.
    nonisolated let modelContainer: ModelContainer?
    var modelContext: ModelContext? {
        modelContainer?.mainContext
    }
    /// Whether the database couldn't be opened and had to be moved aside and recreated during the current launch.
    let databaseWasRecreated: Bool

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
    /// - parameter configuration: Where the module keeps its state and how it performs its uploads.
    /// - parameter categories: A list of well-known ``Category`` definitions.
    convenience init( // swiftlint:disable:this function_default_parameter_at_end
        configuration: Configuration = Configuration(),
        @ArrayBuilder<Category> categories: () -> [Category]
    ) {
        self.init(categories: categories(), configuration: configuration)
    }

    init(categories: [Category], configuration: Configuration) {
        self.categories = Set(categories)
        self.configuration = configuration
        Self.ensureDirectoriesExist(for: configuration, using: FileManager())
        let (container, wasRecreated) = Self.makeModelContainer(for: configuration)
        self.modelContainer = container
        self.databaseWasRecreated = wasRecreated
    }

    func configure() {
        guard modelContainer != nil else {
            logger.warning("Unable to open pending-uploads database; file uploading is disabled for this launch.")
            return
        }
        if databaseWasRecreated {
            logger.warning("The pending-uploads database was unreadable and has been moved aside; previously-pending uploads were dropped.")
        }
        Self.ensureDirectoriesExist(for: configuration, using: fileManager)
        migrateLegacyFileBasedUploads()
        deleteOrphanedStagingFiles()
        // Resume everything that's still pending from previous launches (incl. any just-migrated entries).
        // Routed through `resumePendingUploads()` rather than a bare fetch-and-yield, so that the account-cleanup
        // gate is applied on the one path where it matters most: a launch following a logout whose cleanup didn't finish.
        Swift::Task { [weak self] in
            await self?.resumePendingUploads()
        }
    }

    func isActive(_ category: Category) -> Bool {
        progressByCategory[category] != nil
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
            let url = stagingUrl(forUploadWithId: upload.id)
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }
}


// MARK: On-disk locations

extension ManagedFileUpload {
    nonisolated var stagingDirectory: URL {
        configuration.directory.appending(component: "staging", directoryHint: .isDirectory)
    }

    /// Creates the module's directories if needed, and excludes them from device backups.
    ///
    /// Both directories hold un-uploaded participant data (the staged payloads themselves, and the index describing
    /// them), which must not end up in an iCloud or Finder backup. Marking the *directories* rather than the individual
    /// files means the flag also covers files created later, and survives SQLite recreating its `-wal`/`-shm` sidecars.
    /// Re-stamping on every launch makes it self-healing.
    nonisolated static func ensureDirectoriesExist(for configuration: Configuration, using fileManager: FileManager) {
        for url in [configuration.directory, configuration.databaseDirectory] {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                continue
            }
            var url = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
        let stagingDirectory = configuration.directory.appending(component: "staging", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
    }

    /// Opens the pending-uploads store, moving a genuinely unreadable one aside rather than failing forever.
    ///
    /// - returns: the container (`nil` if it could not be opened at all), and whether an existing store had to be moved aside.
    nonisolated private static func makeModelContainer(for configuration: Configuration) -> (ModelContainer?, Bool) {
        let databaseUrl = configuration.databaseDirectory.appending(component: "db.sqlite", directoryHint: .notDirectory)
        let makeConfiguration = {
            configuration.isStoredInMemoryOnly
                ? ModelConfiguration("ManagedFileUpload", schema: Schema(versionedSchema: SchemaV1.self), isStoredInMemoryOnly: true)
                : ModelConfiguration("ManagedFileUpload", schema: Schema(versionedSchema: SchemaV1.self), url: databaseUrl)
        }
        do {
            return (try makeModelContainer(with: makeConfiguration()), false)
        } catch {
            guard configuration.isStoredInMemoryOnly == false, storeLooksCorrupt(at: databaseUrl) else {
                // Either there is no store to blame, or the failure is environmental (no free space, the file is
                // momentarily unreadable, ...). Treating that as corruption would throw away a perfectly good queue,
                // so the module simply stays inert for this launch and tries again on the next one.
                return (nil, false)
            }
            // The store exists and is readable, but SwiftData still won't open it: most likely corrupt or
            // schema-incompatible. Rather than failing on every subsequent launch, move it aside and start over.
            // (Moved aside, not deleted, so that the previously-pending uploads at least remain recoverable.)
            let fileManager = FileManager()
            for filename in ["db.sqlite", "db.sqlite-shm", "db.sqlite-wal"] {
                let url = configuration.databaseDirectory.appending(component: filename, directoryHint: .notDirectory)
                let brokenUrl = configuration.databaseDirectory.appending(component: "broken-\(filename)", directoryHint: .notDirectory)
                try? fileManager.removeItem(at: brokenUrl)
                try? fileManager.moveItem(at: url, to: brokenUrl)
            }
            return (try? makeModelContainer(with: makeConfiguration()), true)
        }
    }

    nonisolated private static func makeModelContainer(with configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: MigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Whether an existing store file is present and readable, i.e. whether a failure to open it can fairly be
    /// blamed on the store's contents rather than on the environment.
    ///
    /// The app declares no data-protection entitlement, so its files are `completeUntilFirstUserAuthentication` and
    /// remain readable while the device is merely locked — which is exactly when the background drain runs. Testing
    /// readability directly is therefore both more accurate and more specific than asking whether protected data is
    /// currently available.
    nonisolated private static func storeLooksCorrupt(at url: URL) -> Bool {
        guard FileManager().fileExists(atPath: url.path(percentEncoded: false)) else {
            return false
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer {
            try? handle.close()
        }
        return true
    }

    /// Where the file belonging to a ``ScheduledUpload`` is staged.
    ///
    /// Named after the entry's id rather than the file's remote name, which is what makes local collisions
    /// impossible without any locking or renaming; the remote name lives in the entry's `filename`.
    nonisolated func stagingUrl(forUploadWithId id: UUID) -> URL {
        stagingDirectory.appending(component: id.uuidString, directoryHint: .notDirectory)
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
    func resolveCategory(id: String, firebasePath: String) -> Category {
        categories.first { $0.id == id } ?? Category(id: id, title: "\(id)", firebasePath: firebasePath)
    }

    func register(_ category: Category) {
        categories.insert(category)
    }
}


// MARK: Progress Tracking

extension ManagedFileUpload {
    /// Counts a newly-scheduled (or newly-resumed) upload into its category's progress.
    ///
    /// This happens when the upload is enqueued (rather than when it starts getting processed),
    /// so that the progress' total reflects the full queue depth instead of just the currently-in-flight uploads.
    /// Every enqueued upload is matched by exactly one ``completeUploadProgress(for:)`` or
    /// ``abortUploadProgress(for:)`` in `finishUpload(_:category:outcome:)`, on every path.
    func addUploadToProgress(for category: Category) {
        if let progress = progressByCategory[category] {
            progress.totalUnitCount += 1
        } else {
            let progress = Progress(totalUnitCount: 1)
            progress.localizedDescription = String(localized: category.title)
            progressByCategory[category] = progress
        }
    }

    func completeUploadProgress(for category: Category) {
        guard let progress = progressByCategory[category] else {
            return
        }
        progress.completedUnitCount += 1
        if progress.completedUnitCount >= progress.totalUnitCount {
            progressByCategory[category] = nil
        }
    }

    /// Drops all recorded progress, e.g. because everything pending has just been cleared.
    func resetAllProgress() {
        progressByCategory.removeAll()
    }

    /// Drops the recorded progress for a single category.
    func resetProgress(for category: Category) {
        progressByCategory[category] = nil
    }

    /// Un-counts a failed or discarded upload from its category's progress, so that the category doesn't appear active forever.
    func abortUploadProgress(for category: Category) {
        guard let progress = progressByCategory[category] else {
            return
        }
        progress.totalUnitCount -= 1
        if progress.totalUnitCount <= 0 || progress.completedUnitCount >= progress.totalUnitCount {
            progressByCategory[category] = nil
        }
    }
}
