//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseCore
import FirebaseFirestore
import Foundation
@testable import MyHeartCounts
import Testing


@Suite
struct HealthKitStatsFirestoreTests {
    /// A connection lost during a write still permits local visibility and cancellation of the server wait.
    @Test(.timeLimit(.minutes(1)))
    func offlineUpdatesPreserveOtherSources() async throws {
        try await withOfflineFirestore { firestore in
            let month = try #require(HealthKitStatsCalculator.month(containing: Date(timeIntervalSince1970: 1_788_480_000)))
            let destination = HealthKitStatsCalculator.StatsDocumentDestination(metricId: .weight, month: month, entriesKey: .samples)
            let account = firestore.document("users/offline-test")
            let document = account.collection("stats").document("weight").collection("months").document(month.documentId)
            let writer = HealthKitStatsCalculator.FirestoreStatsWriter(accountDoc: account)
            try await verifyOfflineWrite(
                [73], destination: destination, writer: writer, document: document, expected: [.healthKit: [73]]
            )

            let otherSource = HealthKitStatsCalculator.DataSourceID(rawValue: "com.example.manual")
            let otherStats = HealthKitStatsCalculator.MonthlyStatsDocument(
                metric: .weight, entriesKey: .samples, entriesBySourceId: [otherSource: [81]]
            )
            try document.setData(from: otherStats, merge: true)
            try await verifyOfflineWrite(
                [74], destination: destination, writer: writer, document: document, expected: [.healthKit: [74], otherSource: [81]]
            )
            try await verifyOfflineWrite(
                [], destination: destination, writer: writer, document: document, expected: [.healthKit: [], otherSource: [81]]
            )
        }
    }

    private func verifyOfflineWrite(
        _ entries: [Int],
        destination: HealthKitStatsCalculator.StatsDocumentDestination,
        writer: HealthKitStatsCalculator.FirestoreStatsWriter,
        document: DocumentReference,
        expected: [HealthKitStatsCalculator.DataSourceID: [Int]]
    ) async throws {
        let (snapshots, continuation) = AsyncThrowingStream<DocumentSnapshot, any Error>.makeStream()
        let listener = document.addSnapshotListener { snapshot, error in
            if let error {
                continuation.finish(throwing: error)
            } else if let snapshot {
                continuation.yield(snapshot)
            }
        }
        let task = Swift::Task { try await writer.writeStatsDocument(entries, to: destination) }
        defer {
            task.cancel()
            listener.remove()
            continuation.finish()
        }
        for try await snapshot in snapshots {
            guard snapshot.exists,
                  let stats = try? snapshot.data(as: HealthKitStatsCalculator.MonthlyStatsDocument<Int>.self),
                  stats.entriesBySourceId == expected else {
                continue
            }
            #expect(stats.metric == .weight)
            #expect(stats.version == 0)
            #expect(snapshot.metadata.hasPendingWrites)
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
            return
        }
        Issue.record("The locally queued stats never appeared")
    }

    private func withOfflineFirestore(_ operation: (Firestore) async throws -> Void) async throws {
        let name = "health-stats-offline-\(UUID().uuidString)"
        let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
        options.projectID = "demo-health-stats-offline"
        options.apiKey = "A" + String(repeating: "0", count: 38) // Required format; not a real API key.
        FirebaseApp.configure(name: name, options: options)
        let app = try #require(FirebaseApp.app(name: name))
        let firestore = Firestore.firestore(app: app)
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        settings.host = "127.0.0.1:9"
        settings.isSSLEnabled = false
        firestore.settings = settings
        do {
            try await firestore.disableNetwork()
            try await operation(firestore)
            try await firestore.terminate()
        } catch {
            try? await firestore.terminate()
            _ = await app.delete()
            throw error
        }
        #expect(await app.delete())
    }
}
