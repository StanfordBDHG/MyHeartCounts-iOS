//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseStorage
import Foundation
import OSLog
import Synchronization


enum StorageUploadError: Error, Sendable {
    case missingUploadMetadata
}


private final class StorageUploadCancellation: Sendable {
    private struct State {
        var isCancelled = false
        var task: StorageUploadTask?
    }

    private let state = Mutex(State())

    func install(_ task: StorageUploadTask) {
        let shouldCancel = state.withLock { state in
            guard !state.isCancelled else {
                return true
            }
            state.task = task
            return false
        }
        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        let task = state.withLock { state in
            state.isCancelled = true
            let task = state.task
            state.task = nil
            return task
        }
        task?.cancel()
    }
}


extension StorageReference {
    /// Uploads a file, and actually stops when the surrounding task is cancelled.
    ///
    /// `putFileAsync` wraps the callback API in a bare `withCheckedThrowingContinuation`, with no cancellation
    /// handler — so cancelling the task neither stops the transfer nor resumes the caller. That matters here because
    /// cancellation is how the module stops work before wiping an account's data, and how a background task's
    /// expiration stops a transfer that would otherwise be killed by the watchdog.
    ///
    /// The original error is propagated unchanged, so that callers can distinguish an offline failure from a quota or
    /// permission failure by its `NSError` domain and code.
    func putFileRespectingCancellation(
        from url: URL,
        metadata: StorageMetadata
    ) async throws {
        let cancellation = StorageUploadCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let task = putFile(from: url, metadata: metadata) { metadata, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if metadata == nil {
                        continuation.resume(throwing: StorageUploadError.missingUploadMetadata)
                    } else {
                        continuation.resume()
                    }
                }
                cancellation.install(task)
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
}


extension ManagedFileUpload {
    /// Uploads a staged file into the owning account's directory in the Firebase Storage.
    ///
    /// - Note: only ever called when no `uploadOperation` was injected — `Storage.storage()` force-unwraps
    ///     `FirebaseApp.app()`, so merely mentioning it is unsafe in a context where firebase isn't configured.
    @concurrent
    func uploadToFirebaseStorage(
        at fileUrl: URL,
        category: Category,
        accountId: String,
        filename: String,
        metadata: [String: String]
    ) async throws {
        let storageRef = Storage.storage().reference(withPath: "users/\(accountId)/\(category.firebasePath)/\(filename)")
        let bucket = storageRef.bucket
        let path = storageRef.fullPath
        await logger.notice("uploading to \(bucket):\(path)")
        let storageMetadata = StorageMetadata()
        storageMetadata.contentType = "application/octet-stream"
        if !metadata.isEmpty {
            storageMetadata.customMetadata = metadata
        }
        try await storageRef.putFileRespectingCancellation(from: fileUrl, metadata: storageMetadata)
    }
}
