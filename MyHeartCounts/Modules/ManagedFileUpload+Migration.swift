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


extension ManagedFileUpload {
    /// How long an orphaned staging file is kept when we can't tell whether it is genuinely orphaned.
    private static let orphanRetentionInterval: TimeInterval = 14 * 24 * 60 * 60

    /// Migrates pending uploads that were created by the old, file-system-based version of this module into the database.
    ///
    /// The old module tracked its pending uploads as files in one directory per category (within the module's directory),
    /// stored under their remote filenames.
    /// We turn every such file into a ``ScheduledUpload`` entry and move it into the staging directory.
    /// This is a one-time migration in the sense that it moves the files out of the legacy directories as it processes them;
    /// on all subsequent launches there's simply nothing left to migrate.
    ///
    /// - Note: the resulting entries carry no `accountId`: this runs during `configure()`, before firebase has restored
    ///     the session, so there is nobody to attribute them to yet. They are adopted by the signed-in account when
    ///     they are first uploaded — see `resolveOwner(of:in:)`.
    func migrateLegacyFileBasedUploads() {
        guard let modelContext else {
            return
        }
        let accountDataGeneration = LocalPreferencesStore.standard[.accountDataGeneration]
        let pendingMoves: [(srcUrl: URL, upload: ScheduledUpload)] = categories.reduce(into: []) { result, category in
            // construct the URL exactly the way the old module did, so that we look for the files where it put them.
            let legacyDir = configuration.directory.appending(component: category.id, directoryHint: .isDirectory)
            guard fileManager.isDirectory(at: legacyDir) else {
                return
            }
            for url in (try? fileManager.contents(of: legacyDir)) ?? [] where !fileManager.isDirectory(at: url) {
                let upload = ScheduledUpload(
                    category: category,
                    filename: url.lastPathComponent,
                    metadata: [:],
                    accountId: nil,
                    accountDataGeneration: accountDataGeneration
                )
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
                    try fileManager.moveItem(at: srcUrl, to: stagingUrl(forUploadWithId: upload.id))
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
            let legacyDir = configuration.directory.appending(component: category.id, directoryHint: .isDirectory)
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
        let children = (try? fileManager.contents(of: configuration.directory)) ?? []
        for url in children where fileManager.isDirectory(at: url) && url.lastPathComponent != stagingDirectory.lastPathComponent {
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
    func deleteOrphanedStagingFiles() {
        guard let modelContext, let uploads = try? modelContext.fetch(FetchDescriptor<ScheduledUpload>()) else {
            // if we can't read the database, we can't tell which files are orphaned. leave everything in place.
            return
        }
        let validNames = Set(uploads.map { $0.id.uuidString })
        for url in (try? fileManager.contents(of: stagingDirectory)) ?? [] where !validNames.contains(url.lastPathComponent) {
            if databaseWasRecreated {
                // The database was just moved aside, so these files' entries may have been lost rather than
                // legitimately deleted — we can't distinguish "orphaned" from "we forgot about it". Keep them for a
                // while (they remain recoverable alongside the moved-aside database), but don't leak them forever.
                let age = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate
                    .map { Date.now.timeIntervalSince($0) }
                guard let age, age > Self.orphanRetentionInterval else {
                    continue
                }
            }
            logger.notice("Deleting orphaned staging file at \(url.lastPathComponent)")
            try? fileManager.removeItem(at: url)
        }
    }
}
