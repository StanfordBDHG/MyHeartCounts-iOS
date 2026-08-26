//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable type_contents_order

import FirebaseFirestore
import Foundation
import HealthKit
import MyHeartCountsShared
import OSLog
import SpeziAccount
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


/// Fetches the entries of a metric's server-side stats documents, converted into ``QuantitySample``s.
///
/// This is the read-side counterpart to ``HealthKitStatsCalculator``: it observes the `users/{uid}/stats/{metricId}/{year}`
/// collections overlapping the query's time range, decodes the monthly documents, and flattens their entries
/// (across all data sources contained in the documents) into a chronologically sorted list of samples.
///
/// - Note: the resolution of the returned samples is whatever the stats documents store (e.g. hourly buckets);
///     consumers that need coarser aggregates can re-aggregate via `aggregated(using:over:anchor:overallTimeRange:calendar:)`.
@MainActor
@propertyWrapper
struct StatsDocumentsQuery<Element: Sendable>: DynamicProperty {
    typealias MetricID = HealthKitStatsCalculator.MetricID
    /// Converts a decoded stats document into elements, keeping only those within the time range.
    fileprivate typealias DecodeDocumentFn = @Sendable (StatsDocument, _ timeRange: Range<Date>) -> [Element]
    
    @Environment(Account.self)
    private var account: Account?
    
    @State private var impl: Impl
    private let metricId: MetricID
    private let timeRange: HealthKitQueryTimeRange
    /// distinguishes queries over the same metric+timeRange that decode differently (e.g. different aggregation kinds)
    private let discriminator: String
    private let logger = Logger(category: .init("StatsDocumentsQuery"))
    
    var wrappedValue: [Element] {
        impl.elements
    }
    
    fileprivate init(
        metricId: MetricID,
        timeRange: HealthKitQueryTimeRange,
        discriminator: String,
        decode: @escaping DecodeDocumentFn,
        areInIncreasingOrder: @escaping @Sendable (Element, Element) -> Bool
    ) {
        self.metricId = metricId
        self.timeRange = timeRange
        self.discriminator = discriminator
        self._impl = State(wrappedValue: Impl(decodeDocument: decode, areInIncreasingOrder: areInIncreasingOrder))
    }
    
    nonisolated func update() {
        Task { @MainActor in
            guard let accountId = account?.details?.accountId else {
                logger.error("Asked to query stats documents, but no user logged in.")
                return
            }
            impl.setup(
                input: .init(
                    accountId: accountId,
                    metricId: metricId,
                    timeRange: timeRange.range,
                    discriminator: discriminator
                ),
                logger: logger
            )
        }
    }
}


extension StatsDocumentsQuery where Element == QuantitySample {
    /// - parameter metric: the metric whose stats documents should be fetched
    /// - parameter timeRange: the time range to fetch entries for
    /// - parameter aggregationKind: which of a bucketed entry's values (sum, resp. min/max/avg) should be used as the resulting sample's value.
    ///     (Individual-samples entries carry only a single value, and ignore this.)
    init(metric: HealthStatsMetric, timeRange: HealthKitQueryTimeRange, aggregationKind: StatisticsAggregationOption) {
        self.init(
            metricId: metric.id,
            timeRange: timeRange,
            discriminator: String(describing: aggregationKind),
            decode: { document, timeRange in
                document.quantitySamples(for: metric, in: timeRange, aggregationKind: aggregationKind)
            },
            areInIncreasingOrder: { $0.startDate < $1.startDate }
        )
    }
}


extension StatsDocumentsQuery where Element == SleepSessionStatsSample {
    /// Fetches the sleep sessions of the `sleep` metric's stats documents.
    /// (Sleep isn't a quantity sample type, so it doesn't have a ``HealthStatsMetric``.)
    init(sleepSessionsIn timeRange: HealthKitQueryTimeRange) {
        self.init(
            metricId: .sleep,
            timeRange: timeRange,
            discriminator: "sleepSessions",
            decode: { document, timeRange in
                document.sleepSessionSamples(in: timeRange)
            },
            areInIncreasingOrder: { $0.timeRange.upperBound < $1.timeRange.upperBound }
        )
    }
}


extension StatsDocumentsQuery where Element == BloodPressureStatsSample {
    /// Fetches the sys/dia reading pairs of the `blood-pressure` metric's stats documents.
    /// (Blood pressure isn't representable as ``QuantitySample``s, since its entries carry two values.)
    init(bloodPressureIn timeRange: HealthKitQueryTimeRange) {
        self.init(
            metricId: .bloodPressure,
            timeRange: timeRange,
            discriminator: "bloodPressure",
            decode: { document, timeRange in
                document.bloodPressureSamples(in: timeRange)
            },
            areInIncreasingOrder: { $0.date < $1.date }
        )
    }
}


extension StatsDocumentsQuery {
    fileprivate struct QueryInput: Hashable, Sendable {
        let accountId: String
        let metricId: MetricID
        let timeRange: Range<Date>
        let discriminator: String
        
        /// The paths of the `users/{uid}/stats/{metricId}/{year}` collections overlapping the time range.
        var collectionPaths: [String] {
            let cal = Calendar.current
            guard let currentYear = cal.dateComponents([.year], from: .now).year,
                  let firstYear = cal.dateComponents([.year], from: timeRange.lowerBound).year,
                  let lastYear = cal.dateComponents([.year], from: timeRange.upperBound).year,
                  firstYear <= lastYear else {
                return []
            }
            // no stats documents exist for future years (this also handles open-ended time ranges, whose upper bound is `.distantFuture`)
            let clampedLastYear = min(lastYear, currentYear)
            // - the -1: the year a month's document is filed under is determined by the *writer's* time zone at computation time;
            //   observing one extra year on the lower end makes sure we don't miss entries near a year boundary
            // - the max(): safety valve, so we don't observe an unbounded number of collections for huge time ranges (e.g. `.ever`)
            let clampedFirstYear = max(min(firstYear, clampedLastYear) - 1, clampedLastYear - 10)
            return (clampedFirstYear...clampedLastYear).map { year in
                "users/\(accountId)/stats/\(metricId)/\(year)"
            }
        }
    }
    
    
    /// Holds the active listener registrations, and removes them when it gets deallocated.
    /// (Simply dropping a `ListenerRegistration` does not detach the listener; it needs an explicit `remove()` call.)
    private final class ListenerBag: Sendable {
        // SAFETY: only ever accessed from the main actor (and, in deinit, when no other references can exist).
        nonisolated(unsafe) var listeners: [any ListenerRegistration] = []
        
        func removeAll() {
            for listener in listeners {
                listener.remove()
            }
            listeners.removeAll()
        }
        
        deinit {
            removeAll()
        }
    }
    
    
    @Observable
    @MainActor
    fileprivate final class Impl: Sendable {
        @ObservationIgnored private let listeners = ListenerBag()
        @ObservationIgnored private var input: QueryInput?
        @ObservationIgnored private let decodeDocument: DecodeDocumentFn
        @ObservationIgnored private let areInIncreasingOrder: @Sendable (Element, Element) -> Bool
        /// the decoded elements, per collection path. (a time range can span multiple years, i.e. multiple collections.)
        @ObservationIgnored private var elementsByCollection: [String: [Element]] = [:]
        /// per-collection-path snapshot generation counters, so that out-of-order decode completions can't overwrite newer data with older data
        @ObservationIgnored private var snapshotGenerations: [String: Int] = [:]
        private(set) var elements: [Element] = []
        
        init(decodeDocument: @escaping DecodeDocumentFn, areInIncreasingOrder: @escaping @Sendable (Element, Element) -> Bool) {
            self.decodeDocument = decodeDocument
            self.areInIncreasingOrder = areInIncreasingOrder
        }
        
        func setup(input: QueryInput, logger: Logger) {
            guard input != self.input else {
                return
            }
            self.input = input
            listeners.removeAll()
            elementsByCollection.removeAll()
            snapshotGenerations.removeAll()
            elements = []
            for path in input.collectionPaths {
                let listener = Firestore.firestore().collection(path).addSnapshotListener { @Sendable [weak self] snapshot, error in
                    guard let self else {
                        return
                    }
                    if let snapshot {
                        Task {
                            await self.process(snapshot, collectionPath: path, input: input, logger: logger)
                        }
                    } else if let error {
                        logger.error("encountered error in firebase snapshot listener: \(error)")
                    }
                }
                listeners.listeners.append(listener)
            }
        }
        
        private func process(_ snapshot: QuerySnapshot, collectionPath: String, input: QueryInput, logger: Logger) async {
            let generation = (snapshotGenerations[collectionPath] ?? 0) + 1
            snapshotGenerations[collectionPath] = generation
            let elements = await Self.decode(snapshot, input: input, decodeDocument: decodeDocument, logger: logger)
            guard input == self.input, snapshotGenerations[collectionPath] == generation else {
                // the query input changed, or a newer snapshot for this collection was already processed
                return
            }
            self.elementsByCollection[collectionPath] = elements
            self.elements = self.elementsByCollection.values.flatMap { $0 }.sorted(by: areInIncreasingOrder)
        }
        
        @concurrent
        private static func decode(
            _ snapshot: QuerySnapshot,
            input: QueryInput,
            decodeDocument: DecodeDocumentFn,
            logger: Logger
        ) async -> [Element] {
            var elements: [Element] = []
            for document in snapshot.documents {
                let statsDoc: StatsDocument
                do {
                    statsDoc = try document.data(as: StatsDocument.self)
                } catch {
                    logger.error("unable to decode stats document at '\(document.reference.path)': \(error)")
                    continue
                }
                guard statsDoc.version == 0 else {
                    logger.error("skipping stats document at '\(document.reference.path)' with unsupported version \(statsDoc.version)")
                    continue
                }
                elements.append(contentsOf: decodeDocument(statsDoc, input.timeRange))
            }
            return elements
        }
    }
}


// MARK: Document Decoding

extension StatsDocumentsQuery {
    /// Read-side model of a monthly stats document, as written by ``HealthKitStatsCalculator`` (see `docs/MHCDataSpec.md`).
    fileprivate struct StatsDocument: Decodable, Sendable {
        /// The keys under which a stats document can store its entries (grouped by data source).
        /// A document is expected to use exactly one of these; if multiple are present, the first match wins.
        static var entriesKeys: [String] { ["hourly", "daily", "sessions", "samples"] }
        
        let version: Int
        let metric: String
        /// the entries, keyed by data-source identifier (e.g. `com.apple.HealthKit`).
        let entriesBySourceId: [String: [Entry]]
        
        private struct CodingKey: Swift.CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            
            init(stringValue: String) {
                self.stringValue = stringValue
            }
            init?(intValue: Int) {
                nil
            }
        }
        
        /// Wrapper that turns an undecodable element into `nil` instead of failing the containing array.
        /// (We don't want a single malformed entry to discard an entire month of data.)
        private struct LossyEntry: Decodable {
            let entry: Entry?
            
            init(from decoder: any Decoder) throws {
                entry = try? Entry(from: decoder)
            }
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKey.self)
            version = try container.decode(Int.self, forKey: .init(stringValue: "version"))
            metric = try container.decode(String.self, forKey: .init(stringValue: "metric"))
            var entriesBySourceId: [String: [Entry]] = [:]
            for entriesKey in Self.entriesKeys {
                guard let entries = try container.decodeIfPresent([String: [LossyEntry]].self, forKey: .init(stringValue: entriesKey)) else {
                    continue
                }
                entriesBySourceId = entries.mapValues { $0.compactMap(\.entry) }
                break
            }
            self.entriesBySourceId = entriesBySourceId
        }
        
        /// The entries of the document's preferred data source.
        ///
        /// NOTE: the spec models the sources within a stats document as *competing* (e.g., HealthKit and a wearable
        /// integration both covering the same hours), so we must pick one source rather than combine them
        /// (summing entries from two sources covering the same time period would double-count).
        /// For the time being, we prefer HealthKit-derived entries, and otherwise simply use the source with the most entries.
        var preferredSourceEntries: [Entry] {
            entriesBySourceId["com.apple.HealthKit"]
                ?? entriesBySourceId.max { $0.value.count < $1.value.count }?.value
                ?? []
        }
        
        func quantitySamples(
            for metric: HealthStatsMetric,
            in timeRange: Range<Date>,
            aggregationKind: StatisticsAggregationOption
        ) -> [QuantitySample] {
            preferredSourceEntries.compactMap { entry in
                entry.quantitySample(for: metric, in: timeRange, aggregationKind: aggregationKind)
            }
        }
        
        func bloodPressureSamples(in timeRange: Range<Date>) -> [BloodPressureStatsSample] {
            preferredSourceEntries.compactMap { entry in
                entry.bloodPressureSample(in: timeRange)
            }
        }
        
        func sleepSessionSamples(in timeRange: Range<Date>) -> [SleepSessionStatsSample] {
            preferredSourceEntries.compactMap { entry in
                entry.sleepSessionSample(in: timeRange)
            }
        }
    }
    
    
    /// A single entry within a stats document.
    ///
    /// This intentionally models the union of the different entry shapes (bucketed sum, bucketed min/max/avg, individual sample),
    /// so that we can decode all of them with a single type.
    fileprivate struct Entry: Decodable, Sendable {
        // bucketed entries
        let start: String?
        let end: String?
        let sum: Double?
        let min: Double?
        let max: Double?
        let avg: Double?
        // individual-sample entries
        let date: String?
        let value: Double?
        // blood-pressure entries
        let systolic: Double?
        let diastolic: Double?
        // all entries
        let unit: String
        
        /// The time range the entry covers. Empty (`lowerBound == upperBound`) for individual-sample entries.
        var timeRange: Range<Date>? {
            if let start = start.flatMap(Self.parseDate), let end = end.flatMap(Self.parseDate), start <= end {
                start..<end
            } else if let date = date.flatMap(Self.parseDate) {
                date..<date
            } else {
                nil
            }
        }
        
        func quantitySample(
            for metric: HealthStatsMetric,
            in timeRange: Range<Date>,
            aggregationKind: StatisticsAggregationOption
        ) -> QuantitySample? {
            guard let entryTimeRange = self.timeRange,
                  let unit = HKUnit.parse(self.unit),
                  let value = self.value(for: aggregationKind) else {
                return nil
            }
            let overlaps = entryTimeRange.isEmpty
                ? timeRange.contains(entryTimeRange.lowerBound)
                : timeRange.overlaps(entryTimeRange)
            guard overlaps else {
                return nil
            }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            guard quantity.is(compatibleWith: metric.sampleType.canonicalUnit) else {
                // an entry with a unit that's dimensionally incompatible with the metric's sample type
                // (converting would raise an unrecoverable NSException); skip it
                return nil
            }
            return QuantitySample(
                id: UUID(),
                sampleType: .healthKit(metric.sampleType),
                quantity: quantity,
                startDate: entryTimeRange.lowerBound,
                endDate: entryTimeRange.upperBound
            )
        }
        
        func sleepSessionSample(in timeRange: Range<Date>) -> SleepSessionStatsSample? {
            guard let entryTimeRange = self.timeRange,
                  let sum,
                  let unit = HKUnit.parse(self.unit),
                  timeRange.overlaps(entryTimeRange) else {
                return nil
            }
            let quantity = HKQuantity(unit: unit, doubleValue: sum)
            guard quantity.is(compatibleWith: .hour()) else {
                return nil
            }
            return SleepSessionStatsSample(timeRange: entryTimeRange, hoursAsleep: quantity.doubleValue(for: .hour()))
        }
        
        func bloodPressureSample(in timeRange: Range<Date>) -> BloodPressureStatsSample? {
            guard let entryTimeRange = self.timeRange,
                  let systolic,
                  let diastolic,
                  timeRange.contains(entryTimeRange.lowerBound) else {
                return nil
            }
            return BloodPressureStatsSample(date: entryTimeRange.lowerBound, systolic: systolic, diastolic: diastolic)
        }
        
        /// - Note: bucketed entries only carry the values their aggregation produced (e.g. a steps entry only has `sum`);
        ///     requesting an aggregation kind the entry doesn't carry yields `nil`, and the entry is skipped.
        func value(for aggregationKind: StatisticsAggregationOption) -> Double? {
            if let value {
                return value
            }
            return switch aggregationKind {
            case .sum: sum
            case .avg: avg
            case .min: min
            case .max: max
            }
        }
        
        private static func parseDate(_ string: String) -> Date? {
            if let date = try? Date(string, strategy: dateFormat) {
                date
            } else {
                // tolerate other ISO8601 offset spellings (e.g. "Z", or no colon in the offset)
                try? Date(string, strategy: .iso8601)
            }
        }
        
        private static var dateFormat: Date.ISO8601FormatStyle {
            Date.ISO8601FormatStyle(timeZone: .current)
                .year().month().day() // swiftlint:disable:this multiline_function_chains
                .dateTimeSeparator(.standard)
                .time(includingFractionalSeconds: false)
                .timeZone(separator: .colon)
        }
    }
}
