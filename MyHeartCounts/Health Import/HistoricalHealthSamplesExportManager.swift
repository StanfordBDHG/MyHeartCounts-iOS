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
import SpeziHealthKit
import SpeziHealthKitBulkExport
import SpeziStudy


@MainActor
final class HistoricalHealthSamplesExportManager: Module, EnvironmentAccessible, Sendable {
    @Dependency(Account.self)
    private var account: Account?
    
    @Dependency(StudyManager.self)
    private var studyManager
    
    @Dependency(BulkHealthExporter.self)
    private var bulkExporter
    
    @Application(\.logger)
    private var logger
    
    private(set) var session: (any BulkExportSession<HistoricalSamplesToFHIRJSONProcessor>)?
    
    
    func configure() {
        startAutomaticExportingIfNeeded()
        scheduleOrphanedExportsForUpload()
    }
    
    
    /// Schedules all files in the bulkExports folder to be uploaded, unless they have already been scheduled.
    ///
    /// The purpose of this function is to allow us to retry any unsucessful uploads, which failed bc the app was quit, or for some other reason.
    private func scheduleOrphanedExportsForUpload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: .scheduledHealthKitUploads, includingPropertiesForKeys: nil)) ?? []
        guard !urls.isEmpty else {
            return
        }
        Task.detached(priority: .utility) {
            await withDiscardingTaskGroup { taskGroup in
                for url in urls {
                    taskGroup.addTask(priority: .utility) {
                        try? await self.uploadAndDelete(url)
                    }
                }
            }
        }
    }
    
    
    /// Starts the automatic collection of historical health data,
    /// unless it's already running, or automatic collection is disabled via ``FeatureFlags/disableAutomaticBulkHealthExport``.
    nonisolated func startAutomaticExportingIfNeeded() {
        Task {
            await setupAndStartExportSession()
        }
    }
    
    
    /// Cancels the session, deletes all progress associated with it, and restarts it
    ///
    /// - Note: This is intended primarily for debugging purposes
    func fullyResetSession() throws {
        try bulkExporter.deleteSessionRestorationInfo(for: .mhcHistoricalDataExport)
        Task { @Sendable in
            while let session = self.session, session.state != .terminated {
                try await Task.sleep(for: .seconds(1))
            }
            self.session = nil
            await self.setupAndStartExportSession()
        }
    }
    
    
    /// - returns: A Boolean indicating whether the session was successfully set up and started
    @discardableResult
    private func setupAndStartExportSession() async -> Bool {
        if session == nil {
            guard let study = studyManager.studyEnrollments.first?.study else {
                logger.error("\(#function) aborting: no study")
                return false
            }
            do {
                session = try await bulkExporter.session(
                    withId: .mhcHistoricalDataExport,
                    for: study.allCollectedHealthData,
                    startDate: .oldestSample,
                    using: HistoricalSamplesToFHIRJSONProcessor()
                )
            } catch {
                logger.error("Error creating bulk export session: \(error)")
                return false
            }
        }
        // session is nonnil now
        assert(session != nil)
        do {
            logger.notice("Will start BulkHealthExport session")
            let results = try session!.start(retryFailedBatches: true) // swiftlint:disable:this force_unwrapping
            processUploads(for: results.compactMap { $0 })
            return true
        } catch {
            logger.error("Error starting session: \(error)")
            return false
        }
    }
}


// MARK: Upload

extension HistoricalHealthSamplesExportManager {
    private enum UploadError: Error {
        case noAccount
        case uploadFailed(any Error)
        case deletionFailed(any Error)
    }
    
    nonisolated private func processUploads(for stream: some AsyncSequence<URL, Never> & Sendable) {
        Task {
            for await url in stream {
                scheduleForUpload(url)
            }
        }
    }
    
    private nonisolated func scheduleForUpload(_ url: URL) {
        Task.detached(priority: .utility) {
            try await self.uploadAndDelete(url)
        }
    }
    
    /// Uploads the specified file into the current user's `bulkHealthKitUploads` Firebase Storage directory, and deletes the local file afterwards.
    private nonisolated func uploadAndDelete(_ url: URL) async throws(UploadError) {
        await logger.notice("Asked to upload \(url)")
        guard let accountId = await account?.details?.accountId else {
            throw .noAccount
        }
        let storageRef = Storage.storage().reference(withPath: "users/\(accountId)/bulkHealthKitUploads/\(url.lastPathComponent)")
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        do {
            await logger.notice("Will upload \(url)")
            _ = try await storageRef.putFileAsync(from: url, metadata: metadata)
            await logger.notice(" Did upload \(url)")
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


extension BulkExportSessionIdentifier {
    static let mhcHistoricalDataExport = Self("mhcHistoricalDataExport")
}
