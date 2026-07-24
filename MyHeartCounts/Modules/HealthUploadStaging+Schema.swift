//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import GRDB


// MARK: DB + Schema

extension HealthUploadStaging {
    // swiftlint:disable:next type_name
    protocol _PendingEntityRecord: Identifiable<UUID>, FetchableRecord, PersistableRecord, Sendable {
        static var timestampColumn: Column { get }
        static var sampleTypeColumn: Column { get }

        var timestamp: Date { get }
        var sampleType: String { get }
        var sampleId: UUID { get }
    }

    // Note: the record types implement `init(row:)` and `encode(to:)` by hand rather than via Codable,
    // and store the timestamp as epoch seconds: GRDB's Codable-based record coding resolves key paths
    // and formats dates per row, which is too expensive at this table's row volume.
    struct PendingSampleRecord: _PendingEntityRecord {
        enum Columns {
            static let id = Column("id")
            static let timestamp = Column("timestamp")
            static let sampleType = Column("sampleType")
            static let sampleId = Column("sampleId")
            static let fhirJson = Column("fhirJson")
        }
        static let databaseTableName = "pendingSamples"
        static var timestampColumn: Column { Columns.timestamp }
        static var sampleTypeColumn: Column { Columns.sampleType }
        let id: UUID
        let timestamp: Date
        let sampleType: String
        let sampleId: UUID
        /// zstd-compressed
        let fhirJson: Data

        init(id: UUID, timestamp: Date, sampleType: String, sampleId: UUID, fhirJson: Data) {
            self.id = id
            self.timestamp = timestamp
            self.sampleType = sampleType
            self.sampleId = sampleId
            self.fhirJson = fhirJson
        }

        init(row: Row) {
            id = row[Columns.id]
            timestamp = Date(timeIntervalSince1970: row[Columns.timestamp])
            sampleType = row[Columns.sampleType]
            sampleId = row[Columns.sampleId]
            fhirJson = row[Columns.fhirJson]
        }

        func encode(to container: inout PersistenceContainer) {
            container[Columns.id] = id
            container[Columns.timestamp] = timestamp.timeIntervalSince1970
            container[Columns.sampleType] = sampleType
            container[Columns.sampleId] = sampleId
            container[Columns.fhirJson] = fhirJson
        }
    }

    struct PendingDeletionRecord: _PendingEntityRecord {
        enum Columns {
            static let id = Column("id")
            static let timestamp = Column("timestamp")
            static let sampleType = Column("sampleType")
            static let sampleId = Column("sampleId")
        }
        static let databaseTableName = "pendingDeletions"
        static var timestampColumn: Column { Columns.timestamp }
        static var sampleTypeColumn: Column { Columns.sampleType }
        let id: UUID
        let timestamp: Date
        let sampleType: String
        let sampleId: UUID

        init(id: UUID, timestamp: Date, sampleType: String, sampleId: UUID) {
            self.id = id
            self.timestamp = timestamp
            self.sampleType = sampleType
            self.sampleId = sampleId
        }

        init(row: Row) {
            id = row[Columns.id]
            timestamp = Date(timeIntervalSince1970: row[Columns.timestamp])
            sampleType = row[Columns.sampleType]
            sampleId = row[Columns.sampleId]
        }

        func encode(to container: inout PersistenceContainer) {
            container[Columns.id] = id
            container[Columns.timestamp] = timestamp.timeIntervalSince1970
            container[Columns.sampleType] = sampleType
            container[Columns.sampleId] = sampleId
        }
    }


    /// Applies the database schema migrations.
    ///
    /// - parameter targetMigration: The identifier of the last migration to apply; `nil` applies all of them.
    ///     Intended for testing the upgrade path from older schema versions.
    static func applyMigrations(to dbQueue: DatabaseQueue, upTo targetMigration: String? = nil) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "pendingDeletions", options: .strict) {
                $0.primaryKey("id", .blob).notNull() // uuid
                $0.column("timestamp", .text).notNull() // ISO8601 string
                $0.column("sampleType", .text).notNull()
                $0.column("sampleId", .blob).notNull() // uuid
                // have it auto-resolve duplicates, based on sampleType+sampleId
                $0.uniqueKey(["sampleType", "sampleId"], onConflict: .replace)
            }
            try db.create(table: "pendingSamples", options: .strict) {
                $0.primaryKey("id", .blob).notNull() // uuid
                $0.column("timestamp", .text).notNull() // ISO8601 string
                $0.column("sampleType", .text).notNull()
                $0.column("sampleId", .blob).notNull() // uuid
                $0.column("fhirJson", .blob).notNull() // zstd-compressed ModelsR4.ResourceProxy
                // have it auto-resolve duplicates, based on sampleType+sampleId
                $0.uniqueKey(["sampleType", "sampleId"], onConflict: .replace)
            }
        }
        migrator.registerMigration("v2") { db in
            // rebuild both tables with the timestamp stored as epoch seconds (REAL) instead of a
            // datetime string; SQLite can't change a column's type in-place.
            try Self.migrateTimestampToEpoch(db, table: "pendingSamples", extraColumns: ["fhirJson"]) {
                $0.primaryKey("id", .blob).notNull() // uuid
                $0.column("timestamp", .real).notNull() // epoch seconds
                $0.column("sampleType", .text).notNull()
                $0.column("sampleId", .blob).notNull() // uuid
                $0.column("fhirJson", .blob).notNull() // zstd-compressed ModelsR4.ResourceProxy
                // have it auto-resolve duplicates, based on sampleType+sampleId
                $0.uniqueKey(["sampleType", "sampleId"], onConflict: .replace)
            }
            try Self.migrateTimestampToEpoch(db, table: "pendingDeletions", extraColumns: []) {
                $0.primaryKey("id", .blob).notNull() // uuid
                $0.column("timestamp", .real).notNull() // epoch seconds
                $0.column("sampleType", .text).notNull()
                $0.column("sampleId", .blob).notNull() // uuid
                // have it auto-resolve duplicates, based on sampleType+sampleId
                $0.uniqueKey(["sampleType", "sampleId"], onConflict: .replace)
            }
        }
        if let targetMigration {
            try migrator.migrate(dbQueue, upTo: targetMigration)
        } else {
            try migrator.migrate(dbQueue)
        }
    }

    private static func migrateTimestampToEpoch(
        _ db: Database,
        table: String,
        extraColumns: [String],
        body: (TableDefinition) throws -> Void
    ) throws {
        let tmpTable = "\(table)_v2"
        try db.create(table: tmpTable, options: .strict, body: body)
        let extraColumnsSql = extraColumns.isEmpty ? "" : ", " + extraColumns.joined(separator: ", ")
        // the v1 timestamps were written by GRDB as UTC "YYYY-MM-DD HH:MM:SS.SSS" strings, which strftime can parse
        try db.execute(sql: """
            INSERT INTO \(tmpTable) (id, timestamp, sampleType, sampleId\(extraColumnsSql))
            SELECT id, CAST(strftime('%s', timestamp) AS REAL), sampleType, sampleId\(extraColumnsSql)
            FROM \(table)
            """)
        try db.drop(table: table)
        try db.execute(sql: "ALTER TABLE \(tmpTable) RENAME TO \(table)")
    }
}
