//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import GRDB
import HealthKit
import struct ModelsR4.FHIRPrimitive
import struct ModelsR4.Instant
import enum ModelsR4.ResourceProxy
import MyHeartCountsShared
import OSLog
import Spezi
import SpeziFoundation
import SpeziHealthKit


@Observable
@MainActor
final class HealthUploadStagingUploader: Spezi::Module, EnvironmentAccessible, Sendable {
    /// The number of whole days all data will be retained locally, before it is shared with the backend.
    ///
    /// E.g., if this value is `2`, any data collected on monday will be processed on thursday at the earliest.
    /// (To ensure that there are 2 whole days inbetween.)
    nonisolated private static let dataRetentionOffsetInDays = 3

    /// The maximum number of records that are drained (and therefore held in memory) at a time.
    /// Each chunk becomes its own upload file.
    ///
    /// Scales with the memory currently available to the app, within a fixed range;
    /// it is re-evaluated for every chunk, so a drain adapts as memory conditions change.
    nonisolated private static var drainChunkSize: Int {
        // conservative per-record cost while draining: compressed + decompressed payload, plus output buffers
        let bytesPerRecord = 10_000
        let availableMemory = os_proc_available_memory()
        guard availableMemory > 0 else {
            // 0 means the amount couldn't be determined (e.g., on the simulator)
            return 2000
        }
        // spend up to a quarter of the available memory on a chunk: the buffers are transient
        // (freed after each chunk), and os_proc_available_memory is relative to the process's
        // current memory limit, so this scales down automatically when running in the background.
        return min(10_000, max(1000, availableMemory / 4 / bytesPerRecord))
    }

    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(HealthUploadStaging.self) private var healthUploadStaging
    @ObservationIgnored @Dependency(MHCBackgroundTasks.self) private var backgroundTasks
    @ObservationIgnored @Dependency(ManagedFileUpload.self) private var managedFileUpload
    @ObservationIgnored private(set) var currentTask: Task<Void, any Error>?
    // swiftlint:enable attributes
    
    func configure() {
        do {
            try backgroundTasks.register(.processing(
                id: .stagedHealthUpload,
                nextTriggerDate: .absolute(.now.addingTimeInterval(TimeConstants.hour * 6)),
                options: [.requiresNetworkConnectivity]
            ) {
                try await self.process()
            })
        } catch {
            logger.error("Failed to register \(MHCBackgroundTasks.TaskIdentifier.stagedHealthUpload) background task: \(error)")
        }
        Task(priority: .background) {
            // at launch, the drain (and the uploads it produces) only runs if the device is charging,
            // with a staleness fallback; the background task above covers the regular case.
            guard DeviceBattery.shouldRunDeferrableWork(
                lastRun: LocalPreferencesStore.standard[.lastStagedHealthUploadDrain],
                staleness: TimeConstants.day
            ) else {
                return
            }
            do {
                try await process()
            } catch {
                logger.error("Error processing staged health uploads: \(error)")
            }
        }
    }
    
    
    @MainActor
    func process() async throws {
        if let currentTask {
            try await currentTask.value
        } else {
            let task = Task {
                try await _process()
            }
            self.currentTask = task
            try await task.value
        }
    }
    
    @concurrent
    private func _process() async throws {
        let cal = Calendar.current
        let processingCutoff: Date
        if Self.dataRetentionOffsetInDays < 1 {
            processingCutoff = cal.startOfNextDay(for: .now)
        } else {
            guard let cutoff = cal
                .date(byAdding: .day, value: -Self.dataRetentionOffsetInDays, to: .now)
                .flatMap({ cal.startOfDay(for: $0) }) else {
                // should be unreachable
                return
            }
            processingCutoff = cutoff
        }
        await logger.notice("processingCutoff: \(processingCutoff)")
        let healthUploadStaging = await healthUploadStaging
        let managedFileUpload = await managedFileUpload
        // chunks are processed sequentially, to keep the peak memory usage bounded regardless of backlog size
        let didDrainSamples = try await drainPendingSamples(from: healthUploadStaging, to: managedFileUpload, before: processingCutoff)
        let didDrainDeletions = try await drainPendingDeletions(from: healthUploadStaging, to: managedFileUpload, before: processingCutoff)
        if didDrainSamples && didDrainDeletions {
            LocalPreferencesStore.standard[.lastStagedHealthUploadDrain] = .now
        }
    }

    /// - returns: Whether the drain ran to completion, as opposed to stopping early (e.g., because Low Power Mode was enabled).
    @concurrent
    private func drainPendingSamples(
        from healthUploadStaging: HealthUploadStaging,
        to managedFileUpload: ManagedFileUpload,
        before processingCutoff: Date
    ) async throws -> Bool {
        while let chunk = try healthUploadStaging.fetchNextDrainChunk(
            of: HealthUploadStaging.PendingSampleRecord.self,
            before: processingCutoff,
            limit: Self.drainChunkSize
        ) {
            guard !ProcessInfo.processInfo.isLowPowerModeEnabled else {
                return false
            }
            let jsonArray = try chunk.rows.jsonArrayData()
            let compressed = try (consume jsonArray).compressed(using: Zstd.self)
            let url = URL.temporaryDirectory.appending(
                path: "\(chunk.sampleType)_\(UUID().uuidString).json.zstd",
                directoryHint: .notDirectory
            )
            try (consume compressed).write(to: url)
            // the file must be durably staged before the records are removed from the database;
            // and if the removal throws we must abort, since we'd otherwise re-upload the same chunk forever.
            try managedFileUpload.stage(url, category: .liveHealthUpload)
            try healthUploadStaging.remove(chunk)
        }
        return true
    }

    // QUESTION have one CSV per samlpe type, or put them all into a single file?
    /// - returns: Whether the drain ran to completion, as opposed to stopping early (e.g., because Low Power Mode was enabled).
    @concurrent
    private func drainPendingDeletions(
        from healthUploadStaging: HealthUploadStaging,
        to managedFileUpload: ManagedFileUpload,
        before processingCutoff: Date
    ) async throws -> Bool {
        while let chunk = try healthUploadStaging.fetchNextDrainChunk(
            of: HealthUploadStaging.PendingDeletionRecord.self,
            before: processingCutoff,
            limit: Self.drainChunkSize
        ) {
            guard !ProcessInfo.processInfo.isLowPowerModeEnabled else {
                return false
            }
            let csvWriter = try CSVWriter(columns: ["sampleType", "sampleId", "timestamp"])
            for deletion in chunk.rows {
                try csvWriter.appendRow(fields: [
                    deletion.sampleType, deletion.sampleId, deletion.timestamp
                ] as [any CSVWriter.FieldValue])
            }
            let csvData = csvWriter.data()
            let url = URL.temporaryDirectory.appending(
                path: "\(chunk.sampleType)_\(UUID().uuidString).csv.zstd",
                directoryHint: .notDirectory
            )
            try (consume csvData).compressed(using: Zstd.self).write(to: url)
            try managedFileUpload.stage(url, category: .healthDeletions)
            try healthUploadStaging.remove(chunk)
        }
        return true
    }
}


extension Collection where Element == HealthUploadStaging.PendingSampleRecord {
    /// Combines the records' decompressed FHIR JSON payloads into a single JSON array.
    func jsonArrayData() throws -> Data {
        var json = Data()
        json.reserveCapacity(self.reduce(into: 2 + count) { $0 += $1.fhirJson.count * 6 }) // ~6x expected zstd ratio
        json.append(UInt8(ascii: "["))
        var isFirst = true
        for record in self {
            if !isFirst {
                json.append(UInt8(ascii: ","))
            }
            isFirst = false
            json.append(try record.fhirJson.decompressed(using: Zstd.self))
        }
        json.append(UInt8(ascii: "]"))
        return json
    }
}


extension MHCBackgroundTasks.TaskIdentifier {
    static let stagedHealthUpload = Self("edu.stanford.MyHeartCounts.stagedHealthSamplesUpload")
}


extension LocalPreferenceKeys {
    /// The last time the staged health upload drain ran to completion.
    static let lastStagedHealthUploadDrain = LocalPreferenceKey<Date?>("lastStagedHealthUploadDrain")
}
