//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseStorage
import Foundation
import Spezi
import SpeziAccount


@Observable
@MainActor
final class HealthDataFileUploadManager: Module, DefaultInitializable, Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(Account.self) private var account: Account?
    // swiftlint:enable attributes
    
    private let fileManager = FileManager()
    
    /// A `Progress` instance representing the current health upload progress,
    /// i.e. the progress uploading collected historical health samples into the Firebase Storage.
    @MainActor private(set) var uploadProgress: Progress?
    
    nonisolated init() {}
    
    func configure() {
        for category in Category.allCases {
            let url = category.stagingDirUrl
            if !fileManager.isDirectory(at: url) {
                do {
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                } catch {
                    logger.error("Unable to create health uploads staging directory at \(url)")
                }
            }
        }
        scheduleOrphanedExportsForUpload()
    }
    
    /// Schedules all files in the bulkExports folder to be uploaded, unless they have already been scheduled.
    ///
    /// The purpose of this function is to allow us to retry any unsucessful uploads, which failed bc the app was quit, or for some other reason.
    private func scheduleOrphanedExportsForUpload() {
        Task(priority: .utility) {
            await withDiscardingTaskGroup { taskGroup in
                for category in Category.allCases {
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
}


extension HealthDataFileUploadManager {
    private enum UploadError: Error {
        case noAccount
        case uploadFailed(any Error)
        case deletionFailed(any Error)
    }
    
    enum Category: CaseIterable {
        /// The data being uploaded was collected as part of the app's live running data collection
        case liveData
        /// The data being uploaded was collected as part of the app's historical health import
        case historicalData
        
        fileprivate var stagingDirUrl: URL {
            switch self {
            case .liveData: .scheduledLiveHealthKitUploads
            case .historicalData: .scheduledHistoricalHealthKitUploads
            }
        }
        
        fileprivate var firebaseFolderName: String {
            switch self {
            case .liveData: "liveHealthSamples"
            case .historicalData: "historicalHealthSamples"
            }
        }
    }
    
    nonisolated func scheduleForUpload(_ stream: some AsyncSequence<URL, Never> & Sendable, category: Category) {
        Task {
            for await url in stream {
                scheduleForUpload(url, category: category)
            }
        }
    }
    
    nonisolated func scheduleForUpload(_ url: URL, category: Category) {
        Task {
            try await upload(url, category: category)
        }
    }
    
    nonisolated func upload(_ url: URL, category: Category) async throws {
        let stagingUrl = category.stagingDirUrl.appending(path: url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: stagingUrl)
        await Task.yield()
        try await self.uploadAndDelete(stagingUrl, category: category)
    }
    
    @MainActor
    private func incrementTotalNumUploads() {
        if let uploadProgress = self.uploadProgress {
            uploadProgress.totalUnitCount += 1
        } else {
            let progress = Progress(totalUnitCount: 1)
            progress.localizedDescription = String(localized: "Uploading Health Data")
            self.uploadProgress = progress
        }
    }
    
    @MainActor
    private func incrementNumCompletedUploads() {
        uploadProgress?.completedUnitCount += 1
        if uploadProgress?.isFinished == true {
            uploadProgress = nil
        }
    }
    
    /// Uploads the specified file into the current user's `bulkHealthKitUploads` Firebase Storage directory, and deletes the local file afterwards.
    private nonisolated func uploadAndDelete(_ url: URL, category: Category) async throws(UploadError) {
        await MainActor.run {
            incrementTotalNumUploads()
        }
        guard let accountId = await account?.details?.accountId else {
            throw .noAccount
        }
        let storageRef = Storage.storage().reference(withPath: "users/\(accountId)/\(category.firebaseFolderName)/\(url.lastPathComponent)")
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        do {
            await logger.notice("Uploading \(url) to \(storageRef.fullPath)")
            _ = try await storageRef.putFileAsync(from: url, metadata: metadata)
            await incrementNumCompletedUploads()
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


extension URL {
    static var scheduledHistoricalHealthKitUploads: URL {
        URL.documentsDirectory.appending(components: "HealthKitUpload", "historical", directoryHint: .isDirectory)
    }
    
    static var scheduledLiveHealthKitUploads: URL {
        URL.documentsDirectory.appending(components: "HealthKitUpload", "live", directoryHint: .isDirectory)
    }
}
