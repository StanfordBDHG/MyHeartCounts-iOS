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
    nonisolated private static let directory = URL.documentsDirectory.appending(component: "ManagedFileUploading", directoryHint: .isDirectory)
    
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(Account.self) private var account: Account?
    // swiftlint:enable attributes
    
    private(set) var categories: Set<Category>
    nonisolated(unsafe) private let fileManager = FileManager()
    
    /// A `Progress` instance representing each category's upload progress,
    /// i.e. the progress of uploading the category's submitted files into the Firebase Storage.
    @MainActor private(set) var progressByCategory: [Category: Progress] = [:]
    
    /// Creates a new instance of the `ManagedFileUpload` module.
    ///
    /// Even though it is allowed to schedule uploads for categories not specified when initially creating the module (via the `categories` parameter),
    /// it is strongly recommended that all expected categories be specified here.
    /// The reason for this is that the module will use this initial list of categories to resume any pending uploads that remain from previous launches of the app.
    ///
    /// - parameter categories: A list of well-known ``Category`` definitions.
    init(@ArrayBuilder<Category> categories: () -> [Category]) {
        self.categories = Set(categories())
    }
    
    func configure() {
        createStagingDirs(for: categories)
        scheduleOrphanedExportsForUpload()
    }
    
    private func createStagingDirs(for categories: some Collection<Category>) {
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
    @MainActor
    func clearPendingUploads() throws {
        try fileManager.removeItem(at: Self.directory)
        createStagingDirs(for: categories)
    }
    
    @MainActor
    func clearPendingUploads(for category: Category) throws {
        try fileManager.removeItem(at: category.stagingDirUrl)
        createStagingDirs(for: CollectionOfOne(category))
    }
}


extension ManagedFileUpload {
    struct Category: Identifiable, Hashable, Sendable {
        let id: String
        let firebasePath: String
        let title: LocalizedStringResource
        let stagingDirUrl: URL
        
        /// Creates a new Category
        ///
        /// - parameter id: Unique identifier for this category.
        /// - parameter title: User-visible title to be used with uploads in this category
        /// - parameter firebasePath: The folder, relative to the user's directory in the storage bucket, where files uploaded for this category should be stored.
        init(id: String, title: LocalizedStringResource, firebasePath: String) { // swiftlint:disable:this function_default_parameter_at_end
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
        do {
            try stage(url, category: category)
        } catch {
            Task {
                await logger.error("Failed to stage \(url.lastPathComponent) for upload: \(error)")
            }
        }
    }

    /// Moves the file into the category's persistent staging directory and schedules its upload.
    ///
    /// Once this function returns, the file survives app termination: any files remaining in the staging
    /// directory are re-scheduled on the next launch. Use this instead of ``upload(_:category:)`` when the
    /// caller is about to discard its own copy of the data and must not lose it if the upload doesn't finish.
    ///
    /// - returns: The task performing the upload; upload failures are retried on the next launch.
    @discardableResult
    nonisolated func stage(_ url: URL, category: Category) throws -> Task<Void, Never> {
        let stagingDirUrl = category.stagingDirUrl
        if !fileManager.isDirectory(at: stagingDirUrl) {
            try fileManager.createDirectory(at: stagingDirUrl, withIntermediateDirectories: true)
        }
        let stagingUrl = stagingDirUrl.appending(path: url.lastPathComponent)
        try fileManager.moveItem(at: url, to: stagingUrl)
        return Task {
            await registerCategory(category)
            try? await self.uploadAndDelete(stagingUrl, category: category)
        }
    }

    @concurrent
    func upload(_ url: URL, category: Category) async throws {
        await registerCategory(category)
        let stagingUrl = category.stagingDirUrl.appending(path: url.lastPathComponent)
        try fileManager.moveItem(at: url, to: stagingUrl)
        await Task.yield()
        try await self.uploadAndDelete(stagingUrl, category: category)
    }

    @MainActor
    private func registerCategory(_ category: Category) {
        if categories.insert(category).inserted {
            createStagingDirs(for: CollectionOfOne(category))
        }
    }
    
    @MainActor
    private func incrementTotalNumUploads(for category: Category) {
        if let uploadProgress = progressByCategory[category] {
            uploadProgress.totalUnitCount += 1
        } else {
            let progress = Progress(totalUnitCount: 1)
            progress.localizedDescription = String(localized: category.title)
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
        let bucket = storageRef.bucket
        let path = storageRef.fullPath
        await logger.notice("uploading to \(bucket):\(path)")
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        do {
            _ = try await storageRef.putFileAsync(from: url, metadata: metadata)
            await incrementNumCompletedUploads(for: category)
        } catch {
            await logger.error("Upload to \(storageRef.fullPath) failed: \(error)")
            throw .uploadFailed(error)
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw .deletionFailed(error)
        }
    }
}
