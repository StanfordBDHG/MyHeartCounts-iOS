//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import Foundation
import SpeziFirestore


extension HealthKitStatsCalculator {
    struct StatsDocumentDestination: Sendable {
        let metricId: MetricID
        let month: StatsMonth
        let entriesKey: MonthlyStatsDocumentEntriesKey
    }

    protocol StatsDocumentWriting: Sendable {
        func writeStatsDocument<Entry: Codable & Sendable>(_ entries: [Entry], to destination: StatsDocumentDestination) async throws
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
            // The writer may finish successfully even after this task was canceled while awaiting its response.
            try Task.checkCancellation()
            commitAnchor()
        }
    }

    struct FirestoreStatsWriter: StatsDocumentWriting {
        /// Capture the account's reference for the run, rather than resolving the current account during each write.
        let accountDoc: DocumentReference

        func writeStatsDocument<Entry: Codable & Sendable>(_ entries: [Entry], to destination: StatsDocumentDestination) async throws {
            try Task.checkCancellation()
            let doc = accountDoc
                .collection("stats")
                .document(destination.metricId.rawValue)
                .collection("months")
                .document(destination.month.documentId)
            do {
                // The explicit cast selects the Codable-encoding overload. Only replace this source's contribution.
                try await doc.updateData([
                    FieldPath([destination.entriesKey.rawValue, DataSourceID.healthKit.rawValue]): entries
                ] as [AnyHashable: any Codable])
            } catch let error as NSError where error.code == FirestoreErrorCode.notFound.rawValue {
                guard !entries.isEmpty else {
                    // No old contribution exists to clear, so an empty document need not be created.
                    return
                }
                let statsDoc = MonthlyStatsDocument(
                    metric: destination.metricId,
                    entriesKey: destination.entriesKey,
                    entriesBySourceId: [.healthKit: entries]
                )
                try await doc.setData(from: statsDoc)
            }
        }
    }
}
