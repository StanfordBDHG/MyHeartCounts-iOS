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
import SpeziAccount
import SpeziHealthKit
import SpeziHealthKitBulkExport
import SpeziStudy


@Observable
@MainActor
final class HistoricalHealthSamplesExportManager: Module, EnvironmentAccessible, Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @StandardActor private var standard: MyHeartCountsStandard
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(StudyManager.self) private var studyManager: StudyManager?
    @ObservationIgnored @Dependency(Account.self) private var account: Account?
    @ObservationIgnored @Dependency(BulkHealthExporter.self) private var bulkExporter
    @ObservationIgnored @Dependency(ManagedFileUpload.self) var managedFileUpload
    // swiftlint:enable attributes
    
    private(set) var session: (any BulkExportSession<HealthKitSamplesFHIRUploader>)?
    
    // periphery:ignore
    /// The progress of the currently active bulk export, if any.
    var exportProgress: BulkExportSessionProgress? {
        session?.progress
    }
    
    
    func configure() {
        if let account, account.signedIn {
            startAutomaticExportingIfNeeded()
        } else {
            logger.notice("Skipping initial historical upload trigger bc not logged in")
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
    func fullyResetSession(restart: Bool = true) async throws {
        try await bulkExporter.deleteSessionRestorationInfo(for: .mhcHistoricalDataExport)
        self.session = nil
        if restart {
            await self.setupAndStartExportSession()
        }
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
                        logger.notice("Starting historical health upload")
                        session = try await bulkExporter.session(
                            withId: .mhcHistoricalDataExport,
                            for: study.allCollectedHealthData,
                            startDate: startDate,
                            using: HealthKitSamplesFHIRUploader(standard: standard)
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
            managedFileUpload.scheduleForUpload(results.compactMap { $0 }, category: .historicalHealthUpload)
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


extension ManagedFileUpload.Category {
    static let liveHealthUpload = Self(
        id: "HealthKitUpload/live",
        title: "HealthKit Upload (Live)",
        firebasePath: "liveHealthSamples"
    )
    static let historicalHealthUpload = Self(
        id: "HealthKitUpload/historical",
        title: "HealthKit Upload (Historical)",
        firebasePath: "historicalHealthSamples"
    )
}
