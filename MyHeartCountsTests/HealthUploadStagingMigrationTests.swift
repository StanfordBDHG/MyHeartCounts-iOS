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
@testable import MyHeartCounts
import Spezi
import SpeziFoundation
import SpeziHealthKit
import SpeziTesting
import Testing


@Suite
struct HealthUploadStagingMigrationTests {
    private actor FakeStandard: Standard, HealthKitConstraint {
        func handleNewSamples<Sample>(_ addedSamples: some Collection<Sample> & Sendable, ofType sampleType: SampleType<Sample>) {}
        func handleDeletedObjects<Sample>(_ deletedObjects: some Collection<HKDeletedObject> & Sendable, ofType sampleType: SampleType<Sample>) {}
    }

    /// Simulates an existing install upgrading from the v1 database schema,
    /// and checks that all pending records survive the migration unchanged and remain drainable.
    @Test
    func schemaMigrationPreservesData() async throws { // swiftlint:disable:this function_body_length
        let dbUrl = URL.temporaryDirectory.appending(path: "staging-migration-test-\(UUID().uuidString).sqlite3")
        defer {
            try? FileManager.default.removeItem(at: dbUrl)
        }
        let cal = Calendar.current
        let timestamp = try #require(cal.date(from: .init(year: 2026, month: 5, day: 9, hour: 17, minute: 52, second: 30)))
        let sampleRecordId = UUID()
        let sampleId = UUID()
        let deletionRecordId = UUID()
        let deletionSampleId = UUID()
        let fhirJson = "{\"resourceType\":\"Observation\"}"
        let compressedFhirJson = try Data(fhirJson.utf8).compressed(using: Zstd.self)
        do {
            // create a database in the v1 schema, populated the way the app would have populated it:
            // GRDB's Codable-based record encoding stored `Date`s as UTC datetime strings,
            // which is also the default binding used here.
            let dbQueue = try DatabaseQueue(path: dbUrl.path(percentEncoded: false))
            try HealthUploadStaging.applyMigrations(to: dbQueue, upTo: "v1")
            try await dbQueue.write { db in
                try db.execute(
                    sql: "INSERT INTO pendingSamples (id, timestamp, sampleType, sampleId, fhirJson) VALUES (?, ?, ?, ?, ?)",
                    arguments: [sampleRecordId, timestamp, SampleType.stepCount.id, sampleId, compressedFhirJson]
                )
                try db.execute(
                    sql: "INSERT INTO pendingDeletions (id, timestamp, sampleType, sampleId) VALUES (?, ?, ?, ?)",
                    arguments: [deletionRecordId, timestamp, SampleType.heartRate.id, deletionSampleId]
                )
            }
            try dbQueue.close()
        }
        // opening the staging module on the v1 database runs the remaining migrations, as it would on a real upgrade
        let healthUploadStaging = HealthUploadStaging(persistence: .onDisk(url: dbUrl))
        await withDependencyResolution(standard: FakeStandard()) {
            healthUploadStaging
            HealthKit()
        }
        let sampleChunk = try #require(try healthUploadStaging.fetchNextDrainChunk(
            of: HealthUploadStaging.PendingSampleRecord.self,
            before: .now,
            limit: 10
        ))
        let sample = try #require(sampleChunk.rows.first)
        #expect(sampleChunk.rows.count == 1)
        #expect(sample.id == sampleRecordId)
        #expect(sample.sampleType == SampleType.stepCount.id)
        #expect(sample.sampleId == sampleId)
        #expect(sample.fhirJson == compressedFhirJson)
        #expect(abs(sample.timestamp.timeIntervalSince(timestamp)) < 1)
        #expect(String(decoding: try sampleChunk.rows.jsonArrayData(), as: UTF8.self) == "[\(fhirJson)]")
        let deletionChunk = try #require(try healthUploadStaging.fetchNextDrainChunk(
            of: HealthUploadStaging.PendingDeletionRecord.self,
            before: .now,
            limit: 10
        ))
        let deletion = try #require(deletionChunk.rows.first)
        #expect(deletionChunk.rows.count == 1)
        #expect(deletion.id == deletionRecordId)
        #expect(deletion.sampleType == SampleType.heartRate.id)
        #expect(deletion.sampleId == deletionSampleId)
        #expect(abs(deletion.timestamp.timeIntervalSince(timestamp)) < 1)
        // the sampleType+sampleId unique key (and its replace-on-conflict behavior) must survive the table rebuild
        let verifyQueue = try DatabaseQueue(path: dbUrl.path(percentEncoded: false))
        try await verifyQueue.write { db in
            let duplicate = HealthUploadStaging.PendingSampleRecord(
                id: UUID(),
                timestamp: .now,
                sampleType: SampleType.stepCount.id,
                sampleId: sampleId,
                fhirJson: compressedFhirJson
            )
            try duplicate.insert(db)
        }
        try verifyQueue.close()
        #expect(try healthUploadStaging.fetchCount(of: HealthUploadStaging.PendingSampleRecord.self) == 1)
    }
}
