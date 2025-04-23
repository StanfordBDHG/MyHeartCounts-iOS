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


@Observable
@MainActor
final class HistoricalHealthSamplesExportManager: Module, EnvironmentAccessible, Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @Dependency(Account.self)
    private var account: Account?
    
    @ObservationIgnored @Dependency(StudyManager.self)
    private var studyManager: StudyManager?
    
    @ObservationIgnored @Dependency(BulkHealthExporter.self)
    private var bulkExporter
    
    @ObservationIgnored @Application(\.logger)
    private var logger
    // swiftlint:enable attributes
    
    private(set) var session: (any BulkExportSession<HistoricalSamplesToFHIRJSONProcessor>)?
    
    /// A `Progress` instance representing the current health data export progress,
    /// i.e. the progress of fetching historical samples, converting them into FHIR observations, and compressing them.
    var exportProgress: Progress? {
        session?.progress
    }
    
    /// A `Progress` instance representing the current health upload progress,
    /// i.e. the progress uploading collected historical health samples into the Firebase Storage.
    @MainActor private(set) var uploadProgress: Progress?
    
    
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
    func fullyResetSession() async throws {
        try await bulkExporter.deleteSessionRestorationInfo(for: .mhcHistoricalDataExport)
        self.session = nil
        await self.setupAndStartExportSession()
    }
    
    
    /// - returns: A Boolean indicating whether the session was successfully set up and started
    @discardableResult
    private func setupAndStartExportSession() async -> Bool {
        if session == nil {
            guard let study = studyManager?.studyEnrollments.first?.study else {
                logger.error("\(#function) aborting: no study")
                return false
            }
            do {
                session = try await bulkExporter.session(
                    withId: .mhcHistoricalDataExport,
                    for: study.allCollectedHealthData,
                    startDate: .last(DateComponents(year: 5)),
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
    
    @MainActor
    private func incrementTotalNumUploads() {
        if let uploadProgress = self.uploadProgress {
            uploadProgress.totalUnitCount += 1
        } else {
            let progress = Progress(totalUnitCount: 1)
            progress.localizedDescription = String(localized: "Uploading Collected Health Data")
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
    private nonisolated func uploadAndDelete(_ url: URL) async throws(UploadError) {
        await MainActor.run {
            logger.notice("Asked to upload \(url)")
            incrementTotalNumUploads()
        }
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


extension BulkExportSessionIdentifier {
    static let mhcHistoricalDataExport = Self("mhcHistoricalDataExport")
}
