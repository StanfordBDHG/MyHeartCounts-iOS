//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import AsyncAlgorithms
import Dispatch
import Foundation
import GRDB
import HealthKit
import struct ModelsR4.FHIRPrimitive
import struct ModelsR4.Instant
import MyHeartCountsShared
import Spezi
import SpeziFoundation
import SpeziHealthKit


@Observable
final class HealthUploadStaging: Spezi::Module, EnvironmentAccessible, @unchecked Sendable {
    private enum DBError: Error {
        /// Thrown if some database operation fails because there is no database (because creation failed).
        case noDatabase
    }
    
    enum Persistence {
        case onDisk(url: URL)
        case inMemory
        
        static var onDisk: Self {
            .onDisk(url: URL.documentsDirectory.appendingPathComponent("healthObservations.sqlite3"))
        }
    }
    
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored private let dbQueue: DatabaseQueue?
    @ObservationIgnored private let jsonEncoder = JSONEncoder()
    /// Whether, when inserting deletions, the `HealthUploadStaging` should automatically elide (i.e., identify and delete) any matching pending samples.
    @ObservationIgnored private let autoElideUploadsWhenInsertingDeletions: Bool
    // swiftlint:enable attributes
    
    nonisolated init(
        persistence: Persistence,
        autoElideUploadsWhenInsertingDeletions: Bool = true
    ) {
        self.autoElideUploadsWhenInsertingDeletions = autoElideUploadsWhenInsertingDeletions
        do {
            let dbQueue: DatabaseQueue
            switch persistence {
            case .onDisk(let url):
                var configuration = GRDB::Configuration()
                configuration.prepareDatabase { db in
                    // WAL avoids the default rollback journal's write amplification
                    try db.execute(sql: "PRAGMA journal_mode = WAL")
                }
                dbQueue = try DatabaseQueue(
                    path: url.absoluteURL.resolvingSymlinksInPath().path(percentEncoded: false),
                    configuration: configuration
                )
            case .inMemory:
                dbQueue = try DatabaseQueue()
            }
            try Self.applyMigrations(to: dbQueue)
            self.dbQueue = dbQueue
        } catch {
            print("Error creating db: \(error)")
            dbQueue = nil
        }
        jsonEncoder.outputFormatting = [.withoutEscapingSlashes]
    }
    
    func configure() {
        Task(priority: .utility) {
            try? self.elidePendingUploadsWherePossible()
        }
    }
}


extension HealthUploadStaging {
    var isEmpty: Bool {
        get throws {
            guard let dbQueue else {
                return true
            }
            return try dbQueue.read { db in
                let tables = try String.fetchAll(db, sql: """
                    SELECT name FROM sqlite_master WHERE type = 'table'
                    AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
                    """)
                return try tables.allSatisfy { table in
                    try Int.fetchOne(db, sql: "SELECT 1 FROM \(table.quotedDatabaseIdentifier) LIMIT 1") == nil
                }
            }
        }
    }
}


// MARK: Insertion

extension HealthUploadStaging {
    func add(
        _ samples: consuming some Collection<some HealthObservation> & Sendable,
        commonSampleType: String? = nil,
        ingestionTimestamp: Date = .now,
        postprocessResource: @Sendable (FHIRResource) throws -> Void = { _ in }
    ) async throws {
        guard !samples.isEmpty else {
            return
        }
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        if let commonSampleType {
            assert(samples.allSatisfy { $0.sampleTypeIdentifier == commonSampleType })
        }
        try await _add(
            samples,
            commonSampleType: commonSampleType,
            postprocessResource: postprocessResource,
            ingestionTimestamp: ingestionTimestamp,
            into: dbQueue
        )
    }
    
    /// - invariant: `samples` is not empty
    /// - invariant: each sample in `samples` is of type `commonSampleType`
    private func _add(
        _ samples: consuming some Collection<some HealthObservation> & Sendable,
        commonSampleType: String?,
        postprocessResource: @Sendable (FHIRResource) throws -> Void,
        ingestionTimestamp: Date,
        into dbQueue: DatabaseQueue
    ) async throws {
        let issuedDate = FHIRPrimitive<ModelsR4.Instant>(try .init(date: ingestionTimestamp))
        let fhirSamples: [PendingSampleRecord] = try await (consume samples).async.reduce(into: []) { results, observation in
            let sampleType = commonSampleType ?? observation.sampleTypeIdentifier
            let sampleId = observation.id
            let resource = try await observation.turnIntoFHIRResource(
                issuedDate: issuedDate,
                using: healthKit,
                postprocess: postprocessResource
            )
            let fhirJson = try jsonEncoder.encode(consume resource)
            results.append(PendingSampleRecord(
                id: UUID(),
                timestamp: ingestionTimestamp,
                sampleType: sampleType,
                sampleId: sampleId,
                fhirJson: try (consume fhirJson).compressed(using: Zstd.self)
            ))
        }
        try insert(fhirSamples, into: dbQueue)
    }
    
    
    func add<Sample>(_ deletions: some Collection<HKDeletedObject> & Sendable, ofType sampleType: SampleType<Sample>) throws {
        guard !deletions.isEmpty else {
            return
        }
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        let timestamp = Date()
        let deletions: [PendingDeletionRecord] = deletions.map { deletion in
            PendingDeletionRecord(
                id: UUID(),
                timestamp: timestamp,
                sampleType: sampleType.id,
                sampleId: deletion.uuid
            )
        }
        try insertDeletions(deletions, into: dbQueue)
    }
    
    
    /// Inserts pending sample upload records into the database.
    ///
    /// - Note: This exists as a separate function, instead of being directly in the ``add(_:commonSampleType:postprocessResource:)`` function above,
    ///     to work around the compiler requiring us to call the async overload of `dbQueue.write` (because the `add` function is async).
    private func insert(_ pendingSamples: some Collection<PendingSampleRecord>, into dbQueue: DatabaseQueue) throws {
        guard !pendingSamples.isEmpty else {
            return
        }
        try dbQueue.write { db in
            for sample in pendingSamples {
                try sample.insert(db)
            }
        }
    }
    
    
    /// Inserts deletion records into the database, and removes any matching samples.
    private func insertDeletions(_ deletions: some Collection<PendingDeletionRecord>, into dbQueue: DatabaseQueue) throws {
        guard !deletions.isEmpty else {
            return
        }
        try dbQueue.write { db in
            guard autoElideUploadsWhenInsertingDeletions else {
                for deletion in deletions {
                    try deletion.insert(db)
                }
                return
            }
            var numElidedUploads = 0
            for deletion in deletions {
                typealias Col = PendingSampleRecord.Columns
                // try to delete any cached samples matching this deletion record
                let deletedCount = try PendingSampleRecord
                    .filter(Col.sampleType == deletion.sampleType && Col.sampleId == deletion.sampleId)
                    .deleteAll(db)
                numElidedUploads += deletedCount
                if deletedCount > 0 {
                    typealias Col = PendingDeletionRecord.Columns
                    // if we managed to delete any matching samples, we also remove any pending deletions for this UUID & sampleType, if they exist
                    try PendingDeletionRecord
                        .filter(Col.sampleType == deletion.sampleType && Col.sampleId == deletion.sampleId)
                        .deleteAll(db)
                } else {
                    // otherwise, we record the deletion
                    try deletion.insert(db)
                }
            }
            LocalPreferencesStore.standard[.numElidedHealthObservationUploads] += numElidedUploads
        }
    }
    
    
    /// Matches all pending deletion records against pending upload records, and removes any records that appear in both.
    ///
    /// For all deletion records, where there exists at least one matching sample record (with identical sampleType and sampleId),
    /// the deletion record and all matching sample records will be removed from the database.
    ///
    /// - parameter dryRun: Controls whether the operation should actually delete the samples (if `true`), or only compute the statistics (if `false`).
    /// - returns: A summary of the elision results, ie a mapping of each sample type's number of deleted pending samples.
    @discardableResult
    func elidePendingUploadsWherePossible(dryRun: Bool = false) throws -> [String: Int] {
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        typealias SampleCol = PendingSampleRecord.Columns
        typealias DeletionCol = PendingDeletionRecord.Columns
        return if dryRun {
            try dbQueue.read { db in
                let rows = try Row.fetchAll(db, """
                    SELECT s.\(SampleCol.sampleType), COUNT(*) AS count
                    FROM \(PendingSampleRecord.self) s
                    INNER JOIN \(PendingDeletionRecord.self) d
                    ON d.\(DeletionCol.sampleType) = s.\(SampleCol.sampleType) AND d.\(DeletionCol.sampleId) = s.\(SampleCol.sampleId)
                    GROUP BY s.\(SampleCol.sampleType)
                    """ as SQLRequest<Row>)
                return rows.reduce(into: [:]) {
                    $0[$1[SampleCol.sampleType]] = $1["count"]
                }
            }
        } else {
            try dbQueue.write { db in
                // delete & fetch samples w/ matching deletions
                struct Pair: Decodable, FetchableRecord {
                    let sampleType: String
                    let sampleId: UUID
                }
                let elided = try Pair.fetchAll(db, """
                    DELETE from \(PendingSampleRecord.self)
                    WHERE (\(SampleCol.sampleType), \(SampleCol.sampleId)) IN (
                        SELECT \(DeletionCol.sampleType), \(DeletionCol.sampleId) FROM \(PendingDeletionRecord.self)
                    )
                    RETURNING \(SampleCol.sampleType), \(SampleCol.sampleId)
                    """ as SQLRequest<Pair>)
                // delete matched deletions
                for pair in elided {
                    try PendingDeletionRecord
                        .filter(DeletionCol.sampleType == pair.sampleType && DeletionCol.sampleId == pair.sampleId)
                        .deleteAll(db)
                }
                return elided.reduce(into: [:]) {
                    $0[$1.sampleType, default: 0] += 1
                }
            }
        }
    }
}

// MARK: Query

extension HealthUploadStaging {
    struct SampleTypeStats {
        let pendingUploads: [String: Int]
        let pendingDeletions: [String: Int]
    }
    
    func fetchSampleTypeStats() throws -> SampleTypeStats? {
        SampleTypeStats(
            pendingUploads: try fetchSampleTypeCounts(for: PendingSampleRecord.self),
            pendingDeletions: try fetchSampleTypeCounts(for: PendingDeletionRecord.self)
        )
    }
}


// MARK: Other

extension LocalPreferenceKeys {
    // maybe have more fine-grained record-keeping here!
    // (day + sampleType + count?)
    static let numElidedHealthObservationUploads = LocalPreferenceKey("numElidedHealthObservationUploads", default: 0)
}


extension HealthUploadStaging {
    func fetchCount(of type: (some TableRecord).Type) throws -> Int {
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        return try dbQueue.read { db in
            try type.fetchCount(db)
        }
    }
    
    
    func fetchSampleTypeCounts(for type: any _PendingEntityRecord.Type) throws -> [String: Int] {
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        let results = try dbQueue.read { db in
            try Row.fetchAll(db, """
                SELECT sampleType, COUNT(*) AS count
                FROM \(type)
                GROUP BY sampleType
                """ as SQLRequest<Row>)
        }
        return results.reduce(into: [:]) {
            $0[$1["sampleType"], default: 0] += $1["count"]
        }
    }
    
    /// Unconditionally removes all data from the store.
    func clear() throws {
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        try dbQueue.write { db in
            try PendingSampleRecord.deleteAll(db)
            try PendingDeletionRecord.deleteAll(db)
        }
    }
}

extension HealthUploadStaging {
    struct DrainChunk<Value: _PendingEntityRecord>: Sendable {
        let sampleType: String
        let rows: [Value]
    }

    /// Fetches the next chunk of pending records older than `cutoff`, for draining.
    ///
    /// The chunk contains at most `limit` rows, all of a single sample type, which bounds the memory needed to process it.
    /// Callers are expected to process the chunk, ``remove(_:)`` it, and call this function again until it returns `nil`.
    func fetchNextDrainChunk<R: _PendingEntityRecord>(
        of _: R.Type,
        before cutoff: Date,
        limit: Int
    ) throws -> DrainChunk<R>? {
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        let rows = try dbQueue.read { db in
            try R
                .filter(R.timestampColumn < cutoff.timeIntervalSince1970)
                .order(R.sampleTypeColumn)
                .limit(limit)
                .fetchAll(db)
        }
        guard let sampleType = rows.first?.sampleType else {
            return nil
        }
        // rows beyond the sample-type boundary are picked up by the next call
        return DrainChunk(sampleType: sampleType, rows: Array(rows.prefix(while: { $0.sampleType == sampleType })))
    }

    func remove<R>(_ drainChunk: DrainChunk<R>) throws {
        guard let dbQueue else {
            throw DBError.noDatabase
        }
        try dbQueue.write { db in
            _ = try R.deleteAll(db, keys: drainChunk.rows.lazy.map(\.id))
        }
    }
}
