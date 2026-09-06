//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import Foundation


extension HealthKitStatsCalculator {
    struct StatsDocumentDestination: Sendable {
        let metricId: MetricID
        let month: StatsMonth
        let entriesKey: MonthlyStatsDocumentEntriesKey
    }

    protocol StatsDocumentWriting: Sendable {
        func writeStatsDocument<Entry: Codable & Sendable>(
            _ entries: [Entry],
            to destination: StatsDocumentDestination
        ) async throws
    }

    /// Shared by a calculator run; tests supply an in-memory writer instead of Firestore.
    struct StatsPersistence: Sendable {
        let writer: any StatsDocumentWriting

        func persistStatsUpdate<Entry: Codable & Sendable>(
            _ entries: [Entry],
            for destination: StatsDocumentDestination,
            hasDeletions: Bool,
            commitAnchor: () -> Void
        ) async throws {
            try Task.checkCancellation()
            // An empty read alone can mean lost read authorization; only an explicit deletion allows clearing old entries.
            if !entries.isEmpty || hasDeletions {
                try await writer.writeStatsDocument(entries, to: destination)
            }
            try Task.checkCancellation()
            commitAnchor()
        }
    }

    struct FirestoreStatsWriter: StatsDocumentWriting {
        /// Capture the account's reference for the run, rather than resolving the current account during each write.
        let accountDoc: DocumentReference

        /// Firestore's completion waits for the server; cancel only our wait, leaving the SDK's queued write intact.
        private static func waitForCompletion(
            _ start: (@escaping @Sendable ((any Error)?) -> Void) throws -> Void
        ) async throws {
            try Task.checkCancellation()
            let (result, continuation) = AsyncThrowingStream<Void, any Error>.makeStream()
            try start { error in
                continuation.finish(throwing: error)
            }
            for try await _ in result { }
            // AsyncThrowingStream ends promptly on cancellation; a late server callback cannot resume this operation.
            try Task.checkCancellation()
        }

        func writeStatsDocument<Entry: Codable & Sendable>(
            _ entries: [Entry],
            to destination: StatsDocumentDestination
        ) async throws {
            try Task.checkCancellation()
            let doc = accountDoc
                .collection("stats")
                .document(destination.metricId.rawValue)
                .collection("months")
                .document(destination.month.documentId)
            let sourceField = FieldPath([destination.entriesKey.rawValue, DataSourceID.healthKit.rawValue])
            if entries.isEmpty {
                // Clear only an existing contribution; a deletion must not create an empty month document.
                try await Self.waitForCompletion { completion in
                    doc.updateData([sourceField: [Any]()]) { error in
                        completion((error as NSError?)?.code == FirestoreErrorCode.notFound.rawValue ? nil : error)
                    }
                }
                return
            }
            let statsDoc = MonthlyStatsDocument(
                metric: destination.metricId,
                entriesKey: destination.entriesKey,
                entriesBySourceId: [.healthKit: entries]
            )
            // Only replace HealthKit's source, and wait for acknowledgement before producing another full snapshot.
            try await Self.waitForCompletion { completion in
                try doc.setData(from: statsDoc, mergeFields: ["version", "metric", sourceField], completion: completion)
            }
        }

        /// Drain writes queued before cancellation or a previous launch before producing more snapshots.
        /// Firestore's barrier covers all pending writes for the current user, including other collections.
        func waitForPendingWrites() async throws {
            try await Self.waitForCompletion { completion in
                accountDoc.firestore.waitForPendingWrites(completion: completion)
            }
        }
    }
}
