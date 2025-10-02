//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseStorage
import Foundation
import OSLog
import Spezi
import SpeziHealthKit
import SpeziHealthKitBulkExport
import SpeziStudy


@Observable
@MainActor
final class HistoricalHealthSamplesExportManager: Module, EnvironmentAccessible, Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger)
    private var logger
    
    @ObservationIgnored @Dependency(StudyManager.self)
    private var studyManager: StudyManager?
    
    @ObservationIgnored @Dependency(BulkHealthExporter.self)
    private var bulkExporter
    
    @ObservationIgnored @Dependency(HealthDataFileUploadManager.self)
    var fileUploader
    // swiftlint:enable attributes
    
    private(set) var session: (any BulkExportSession<HealthKitSamplesToFHIRJSONProcessor>)?
    
    // periphery:ignore
    /// A `Progress` instance representing the current health data export progress,
    /// i.e. the progress of fetching historical samples, converting them into FHIR observations, and compressing them.
    var exportProgress: Progress? {
        session?.progress
    }
    
    
    func configure() {
        startAutomaticExportingIfNeeded()
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
        guard !FeatureFlags.disableAutomaticBulkHealthExport else {
            return false
        }
        if session == nil {
            guard let study = studyManager?.studyEnrollments.first?.studyBundle?.studyDefinition else {
                logger.error("\(#function) aborting: no study")
                return false
            }
            for component in study.healthDataCollectionComponents {
                switch component.historicalDataCollection {
                case .disabled:
                    continue
                case .enabled(let startDate):
                    do {
                        session = try await bulkExporter.session(
                            withId: .mhcHistoricalDataExport,
                            for: study.allCollectedHealthData,
                            startDate: startDate,
                            using: HealthKitSamplesToFHIRJSONProcessor()
                        )
                    } catch {
                        logger.error("Error creating bulk export session: \(error)")
                        return false
                    }
                }
            }
        }
        guard let session else {
            return false
        }
        do {
            logger.notice("Will start BulkHealthExport session")
            let results = try session.start(retryFailedBatches: true)
            fileUploader.scheduleForUpload(results.compactMap { $0 }, category: .historicalData)
            return true
        } catch {
            logger.error("Error starting session: \(error)")
            return false
        }
    }
}


extension BulkExportSessionIdentifier {
    static let mhcHistoricalDataExport = Self("mhcHistoricalDataExport")
}
