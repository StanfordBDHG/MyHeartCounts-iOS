//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziAccount
import SpeziFoundation
import SwiftData


// MARK: Draining

extension ManagedFileUpload {
    /// Starts the loop that performs the queued uploads, at most `maximumConcurrentUploads` at a time.
    ///
    /// Started from `configure()` rather than from a `ServiceModule`'s `run()`, so that it also runs on launches
    /// that never connect a scene. The stream is never finished, so the task must not keep the module alive.
    func startDrainingIfNeeded() {
        guard drainTask == nil else {
            return
        }
        let stream = newUploads.stream
        let limit = configuration.maximumConcurrentUploads
        drainTask = Swift::Task { [weak self] in
            await withManagedTaskQueue(limit: limit) { taskQueue in
                for await uploadId in stream {
                    taskQueue.addTask { [weak self] in
                        await self?.performUpload(uploadId)
                    }
                }
            }
        }
    }

    /// Hands an upload to the queue, counting it into its category's progress.
    ///
    /// Ignored if the queue is closed, or if this upload is already in flight.
    func enqueue(_ uploadId: PersistentIdentifier, category: Category) {
        guard acceptsUploads, enqueuedUploads[uploadId] == nil else {
            return
        }
        enqueuedUploads[uploadId] = category
        addUploadToProgress(for: category)
        newUploads.continuation.yield(uploadId)
    }

    private func performUpload(_ uploadId: PersistentIdentifier) async {
        guard acceptsUploads, let modelContainer, activeUploads[uploadId] == nil else {
            // The queue was closed (or the store is gone) between this upload being enqueued and picked up.
            // Its entry survives; a later `resumePendingUploads()` or the next launch will retry it.
            finishUpload(uploadId, outcome: .failed)
            return
        }
        let task = Swift::Task { [weak self] in
            await self?.upload(uploadId, in: modelContainer) ?? .failed
        }
        activeUploads[uploadId] = task
        let outcome = await task.value
        finishUpload(uploadId, outcome: outcome)
    }

    /// The single balanced exit for every enqueued upload, on every path.
    private func finishUpload(_ uploadId: PersistentIdentifier, outcome: UploadOutcome) {
        activeUploads[uploadId] = nil
        if let category = enqueuedUploads.removeValue(forKey: uploadId) {
            switch outcome {
            case .completed:
                completeUploadProgress(for: category)
            case .failed, .discarded:
                abortUploadProgress(for: category)
            }
        }
        signalQuiescenceIfIdle()
    }
}


// MARK: Quiescence

extension ManagedFileUpload {
    /// Waits until every accepted upload has finished one attempt.
    func waitUntilQuiescent() async {
        guard !enqueuedUploads.isEmpty || !activeUploads.isEmpty else {
            return
        }
        await withCheckedContinuation { continuation in
            quiescenceWaiters.append(continuation)
        }
    }

    /// Closes the queue, cancels every in-flight upload, and waits for them to actually stop.
    ///
    /// Every destructive operation sits on this: it is what makes "no upload is touching the staged files or the
    /// database" true, rather than merely likely. Closing the queue first is what makes the wait terminate — uploads
    /// that were enqueued but not yet started hit the closed-queue check in `performUpload(_:)` and finish immediately,
    /// and nothing new can be added behind our back.
    func cancelAndWaitForQuiescence() async {
        acceptsUploads = false
        for task in activeUploads.values {
            task.cancel()
        }
        await waitUntilQuiescent()
    }

    private func signalQuiescenceIfIdle() {
        guard enqueuedUploads.isEmpty, activeUploads.isEmpty else {
            return
        }
        let waiters = quiescenceWaiters
        quiescenceWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}


// MARK: Resuming

extension ManagedFileUpload {
    /// Re-queues every upload that is still pending, and re-opens the queue if it was closed.
    ///
    /// Returns once the pending uploads have been queued — *not* once they have been uploaded. Callers await this
    /// as part of handling an account association, so anything slower than that would stall every login behind the
    /// entire backlog.
    func resumePendingUploads() async {
        // Unconditionally first, before any gate: every early return below must still leave the queue open.
        // (A clear that is followed by a resume which bails out — nobody signed in yet, cleanup still pending —
        // would otherwise leave the queue closed for the rest of the launch.)
        acceptsUploads = true
        startDrainingIfNeeded()
        guard let modelContainer else {
            return
        }
        guard !configuration.isCleanupPending() else {
            logger.notice("Not resuming pending uploads while cleanup from the previous account is pending")
            return
        }
        guard let accountId = await currentAccountId(), !accountId.isEmpty else {
            return
        }
        for pending in await loadPendingUploads(from: modelContainer) {
            enqueue(
                pending.persistentId,
                category: resolveCategory(id: pending.categoryId, firebasePath: pending.categoryFirebasePath)
            )
        }
    }

    /// Snapshots the pending uploads on a throwaway background context.
    ///
    /// Deliberately not the `mainContext`: fetching there would register every pending model object for the lifetime
    /// of the process, which is the one place a large backlog could turn into a launch-time memory problem.
    @concurrent
    private func loadPendingUploads(from container: ModelContainer) async -> [PendingUpload] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ScheduledUpload>(sortBy: [SortDescriptor(\.creationDate)])
        guard let uploads = try? context.fetch(descriptor) else {
            return []
        }
        return uploads.map {
            PendingUpload(
                persistentId: $0.persistentModelID,
                categoryId: $0.categoryId,
                categoryFirebasePath: $0.categoryFirebasePath
            )
        }
    }
}


// MARK: Performing a single upload

extension ManagedFileUpload {
    @concurrent
    private func upload(_ uploadId: PersistentIdentifier, in container: ModelContainer) async -> UploadOutcome {
        let context = ModelContext(container)
        guard let upload: ScheduledUpload = context.existingModel(for: uploadId) else {
            // The entry was cleared between being queued and being picked up.
            return .discarded
        }
        let fileUrl = stagingUrl(forUploadWithId: upload.id)
        guard let owner = await validatedOwner(of: upload, at: fileUrl, in: context) else {
            return .discarded
        }
        return await transfer(upload, at: fileUrl, owner: owner, in: context)
    }

    /// Checks that the upload can still legitimately be performed, dropping its entry if it cannot.
    ///
    /// - returns: the owning account id, or `nil` if the entry was discarded.
    @concurrent
    private func validatedOwner(
        of upload: ScheduledUpload,
        at fileUrl: URL,
        in context: ModelContext
    ) async -> String? {
        guard fileManager.fileExists(atPath: fileUrl.path(percentEncoded: false)) else {
            await logger.error("Discarding scheduled upload \(upload.id): its staged file is missing.")
            context.delete(upload)
            try? context.save()
            return nil
        }
        guard let owner = await resolveOwner(of: upload, in: context) else {
            let filename = upload.filename
            let categoryId = upload.categoryId
            let size = (try? fileUrl.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            // Uploading it under the current account would deposit the previous participant's data in the new
            // participant's directory; keeping it would retain that data on the device indefinitely. Log enough
            // for the loss to be observable, then drop it.
            await logger.error("""
                Discarding scheduled upload \(upload.id) ('\(filename)', category '\(categoryId)', \(size) bytes): \
                it belongs to a different account.
                """)
            context.delete(upload)
            try? context.save()
            try? fileManager.removeItem(at: fileUrl)
            return nil
        }
        return owner
    }

    @concurrent
    private func transfer(
        _ upload: ScheduledUpload,
        at fileUrl: URL,
        owner: String,
        in context: ModelContext
    ) async -> UploadOutcome {
        let category = await resolveCategory(id: upload.categoryId, firebasePath: upload.categoryFirebasePath)
        let filename = upload.filename
        let customMetadata = upload.metadata
        upload.numAttempts += 1
        try? context.save()
        do {
            if let uploadOperation = configuration.uploadOperation {
                // Checked before touching any Firebase symbol: `Storage.storage()` force-unwraps `FirebaseApp.app()`,
                // and the unit test host launches with firebase disabled.
                try await uploadOperation(fileUrl, category, owner, filename, customMetadata)
            } else {
                try await uploadToFirebaseStorage(
                    at: fileUrl,
                    category: category,
                    accountId: owner,
                    filename: filename,
                    metadata: customMetadata
                )
            }
        } catch {
            if !Swift::Task.isCancelled {
                await logger.error("Upload of '\(filename)' failed: \(error)")
            }
            return .failed
        }
        // The transfer succeeded, so the entry is done regardless of whether we were cancelled in the meantime;
        // dropping it here is what keeps a cancelled drain from re-uploading the same bytes on the next launch.
        context.delete(upload)
        try? context.save()
        do {
            try fileManager.removeItem(at: fileUrl)
        } catch {
            // Not a problem: the file is orphaned now that its entry is gone, and the next launch's sweep removes it.
            await logger.error("Unable to delete uploaded file at \(fileUrl.lastPathComponent): \(error)")
        }
        return .completed
    }

    /// Determines which account's storage directory this upload belongs in.
    ///
    /// - returns: the owning account id, or `nil` if the upload must not be performed right now.
    @concurrent
    private func resolveOwner(of upload: ScheduledUpload, in context: ModelContext) async -> String? {
        guard let accountId = await currentAccountId(), !accountId.isEmpty else {
            return nil
        }
        guard let owner = upload.accountId else {
            // An entry created by the one-time migration from the old, file-system-based module. It carries no owner
            // because that migration runs before firebase has restored the session. Adopt it for the current account,
            // but only while the app isn't telling us that data from a previous account may still be lying around —
            // which is precisely what `pendingAccountDataCleanupRequired` means.
            guard !configuration.isCleanupPending() else {
                return nil
            }
            upload.accountId = accountId
            try? context.save()
            return accountId
        }
        return owner == accountId ? owner : nil
    }

    /// The id of the currently signed-in account, or `nil` if there isn't one.
    @concurrent
    func currentAccountId() async -> String? {
        if let accountIdProvider = configuration.accountIdProvider {
            return await accountIdProvider()
        }
        return await MainActor.run {
            // `signedIn` matters as well as the details being present: the details linger for a moment after a
            // sign-out, and an empty id would produce the path `users//…`, which no storage rule protects.
            guard let account, account.signedIn, let accountId = account.details?.accountId, !accountId.isEmpty else {
                return nil
            }
            return accountId
        }
    }
}
