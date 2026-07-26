//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseStorage
import Foundation


private enum StorageUploadError: Error, Sendable {
    case failed(String)
}


private final class StorageUploadCancellation: @unchecked Sendable {
    // Protected by lock.
    private let lock = NSLock()
    private var isCancelled = false
    private var task: StorageUploadTask?

    func install(_ task: StorageUploadTask) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            task.cancel()
        } else {
            self.task = task
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }
}


extension StorageReference {
    func putFileRespectingCancellation(
        from url: URL,
        metadata: StorageMetadata
    ) async throws {
        let cancellation = StorageUploadCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let task = putFile(from: url, metadata: metadata) { metadata, error in
                    if let error {
                        continuation.resume(throwing: StorageUploadError.failed(String(describing: error)))
                    } else if metadata == nil {
                        continuation.resume(throwing: StorageUploadError.failed("Missing upload metadata"))
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
