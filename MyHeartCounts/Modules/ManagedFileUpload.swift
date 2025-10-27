//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseStorage
import Foundation
import OSLog
import Spezi
import SpeziAccount
import SpeziFoundation


@Observable
@MainActor
final class ManagedFileUpload: Module, EnvironmentAccessible, Sendable {
    nonisolated static let directory = URL.documentsDirectory.appending(component: "ManagedFileUploading", directoryHint: .isDirectory)
    
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(Account.self) private var account: Account?
    // swiftlint:enable attributes
    
    let categories: [Category]
    private let fileManager = FileManager()
    
    /// A `Progress` instance representing each category's upload progress,
    /// i.e. the progress of uploading the category's submitted files into the Firebase Storage.
    @MainActor private(set) var progressByCategory: [Category: Progress] = [:]
    
    init(@ArrayBuilder<Category> categories: () -> [Category]) {
        self.categories = categories()
    }
    
    func configure() {
        for category in categories {
            let url = category.stagingDirUrl
            if !fileManager.isDirectory(at: url) {
                do {
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                } catch {
                    logger.error("Unable to create staging directory at \(url)")
                }
            }
        }
        scheduleOrphanedExportsForUpload()
    }
    
    /// Schedules all files in the different categories' folders to be uploaded, unless they have already been scheduled.
    ///
    /// The purpose of this function is to allow us to retry any unsucessful uploads, which failed bc the app was quit, or for some other reason.
    private func scheduleOrphanedExportsForUpload() {
        Task(priority: .utility) {
            await withDiscardingTaskGroup { taskGroup in
                for category in categories {
                    let files = (try? fileManager.contents(of: category.stagingDirUrl)) ?? []
                    for url in files {
                        taskGroup.addTask(priority: .utility) {
                            try? await self.uploadAndDelete(url, category: category)
                        }
                    }
                }
            }
        }
    }
    
    func isActive(_ category: Category) -> Bool {
        progressByCategory[category] != nil
    }
}


extension ManagedFileUpload {
    struct Category: Identifiable, Hashable, Sendable {
        let id: String
        let firebasePath: String
        fileprivate let title: LocalizedStringResource?
        fileprivate let stagingDirUrl: URL
        
        /// Creates a new Category
        ///
        /// - parameter id: Unique identifier for this category.
        /// - parameter title: Optional, potentially user-visible title to be used with uploads in this category
        /// - parameter firebasePath: The folder, relative to the user's directory in the storage bucket, where files uploaded for this category should be stored.
        init(id: String, title: LocalizedStringResource? = nil, firebasePath: String) { // swiftlint:disable:this function_default_parameter_at_end
            self.id = id
            self.title = title
            self.firebasePath = firebasePath
            self.stagingDirUrl = ManagedFileUpload.directory.appending(component: id, directoryHint: .isDirectory)
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
}


extension ManagedFileUpload {
    private enum UploadError: Error {
        case noAccount
        case uploadFailed(any Error)
        case deletionFailed(any Error)
    }
    
    nonisolated func scheduleForUpload<S: AsyncSequence<URL, Never>>(
        _ sequence: S,
        category: Category
    ) where S: Sendable, S.AsyncIterator: SendableMetatype {
        Task {
            for await url in sequence {
                scheduleForUpload(url, category: category)
            }
        }
    }
    
    nonisolated func scheduleForUpload(_ url: URL, category: Category) {
        Task { @MainActor in
            logger.notice("Scheduling for upload≥ in category \(category.id): \(url)")
        }
        Task {
            try await upload(url, category: category)
        }
    }
    
    @concurrent
    func upload(_ url: URL, category: Category) async throws {
        let stagingUrl = category.stagingDirUrl.appending(path: url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: stagingUrl)
        await Task.yield()
        try await self.uploadAndDelete(stagingUrl, category: category)
    }
    
    @MainActor
    private func incrementTotalNumUploads(for category: Category) {
        if let uploadProgress = progressByCategory[category] {
            uploadProgress.totalUnitCount += 1
        } else {
            let progress = Progress(totalUnitCount: 1)
            if let title = category.title {
                progress.localizedDescription = String(localized: title)
            }
            progressByCategory[category] = progress
        }
    }
    
    @MainActor
    private func incrementNumCompletedUploads(for category: Category) {
        progressByCategory[category]?.completedUnitCount += 1
        if progressByCategory[category]?.isFinished == true {
            progressByCategory[category] = nil
        }
    }
    
    /// Uploads the specified file into the current user's `bulkHealthKitUploads` Firebase Storage directory, and deletes the local file afterwards.
    @concurrent
    private func uploadAndDelete(_ url: URL, category: Category) async throws(UploadError) {
        await MainActor.run {
            incrementTotalNumUploads(for: category)
        }
        guard let accountId = await account?.details?.accountId else {
            throw .noAccount
        }
        let storageRef = Storage.storage().reference(withPath: "users/\(accountId)/\(category.firebasePath)/\(url.lastPathComponent)")
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        do {
            await logger.notice("Uploading \(url) to \(storageRef.fullPath)")
            _ = try await storageRef.putFileAsync(from: url, metadata: metadata)
            await incrementNumCompletedUploads(for: category)
        } catch {
            throw .uploadFailed(error)
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw .deletionFailed(error)
        }
    }
}
