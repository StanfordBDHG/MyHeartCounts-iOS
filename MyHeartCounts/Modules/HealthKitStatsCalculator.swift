//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_length

import FirebaseFirestore
import Foundation
import HealthKit
import MyHeartCountsShared
import OSLog
import Spezi
import SpeziAccount
import SpeziFirestore
import SpeziFoundation
import SpeziHealthKit


@Observable
final class HealthKitStatsCalculator: ServiceModule, EnvironmentAccessible, @unchecked Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(Account.self) private var account
    // swiftlint:enable attributes

    func run() async {
        await account.waitForAccountDetailsReady()
        guard let accountId = await account.details?.accountId else {
            logger.error("no accountId")
            return
        }
        guard let enrollmentDate = await account.details?.dateOfEnrollment else {
            logger.error("no enrollment date")
            return
        }
        let months = self.months(since: enrollmentDate)
        let accountDoc = FirebaseFirestore.Firestore.firestore().document("/users/\(accountId)")
        let startTS = ContinuousClock.now
        logger.notice("starting")
        // NOTE/IDEA: in addition to parallelising over sample type, we could additionally also parallelise over time?
        // (i.e., process multiple months in parallel?)
        await withDiscardingTaskGroup { taskGroup in
            func schedule(_ operation: sending @escaping @isolated(any) () async throws -> Void) {
                taskGroup.addTask {
                    do {
                        try await operation()
                    } catch {
                        self.logger.error("error computing stats: \(error)")
                    }
                }
            }
            for descriptor in Self.bucketedDescriptors {
                schedule {
                    try await self.runBucketedQuantityStats(descriptor, months: months, accountDoc: accountDoc)
                }
            }
            for descriptor in Self.individualSamplesDescriptors {
                schedule {
                    try await self.runIndividualQuantitySampleStats(descriptor, months: months, accountDoc: accountDoc)
                }
            }
            schedule {
                try await self.runSleepStats(months: months, accountDoc: accountDoc)
            }
            schedule {
                try await self.runBloodPressureStats(months: months, accountDoc: accountDoc)
            }
        }
        logger.notice("Completed stats calculation. Took \(startTS.duration(to: .now))")
    }
}


// MARK: Types

extension HealthKitStatsCalculator {
    protocol _IDType: RawRepresentable<String>, LosslessStringConvertible, Hashable, Codable, CodingKeyRepresentable, Sendable { // swiftlint:disable:this type_name line_length
        var rawValue: String { get }
        init(rawValue: String)
    }
    
    struct DataSourceID: _IDType {
        static let healthKit = Self(rawValue: "com.apple.HealthKit")
        
        let rawValue: String
    }
    
    
    struct MetricID: _IDType {
        static let steps = Self(rawValue: "steps")
        static let exerciseTime = Self(rawValue: "exercise-time")
        static let heartRate = Self(rawValue: "heart-rate")
        static let weight = Self(rawValue: "weight")
        static let height = Self(rawValue: "height")
        static let bmi = Self(rawValue: "bmi")
        static let sleep = Self("sleep")
        static let bloodPressure = Self("blood-pressure")
        
        let rawValue: String
    }
}


extension HealthKitStatsCalculator._IDType {
    var description: String {
        rawValue
    }
    init(_ description: String) {
        self.init(rawValue: description)
    }
}

// Making these `CodingKeyRepresentable` means that we can use them as Dictionary keys and still get regular `key: value`
// mappings as the encoded output; otherwise a dictionary `[key1: value1, key2: value2, ...]` would get turned into an array
// of `[key1, value1, key2, value2, ...]` entries.
extension HealthKitStatsCalculator._IDType {
    var codingKey: any Swift.CodingKey {
        AnyCodingKey(stringValue: rawValue)
    }
    
    init?(codingKey: some Swift.CodingKey) {
        self.init(rawValue: codingKey.stringValue)
    }
}


// MARK: Month iteration & document writing

extension HealthKitStatsCalculator {
    fileprivate struct StatsMonth {
        let year: Int
        let monthString: String // zero-padded
        
        /// The id of the month's stats document (within the metric's `months` subcollection), e.g. `2026-08`.
        /// Zero-padded so that the ids' lexicographic order matches their chronologic order.
        var documentId: String {
            "\(year)-\(monthString)"
        }
        let range: Range<Date>
    }

    /// The months the stats should cover, i.e. all months from the user's enrollment up to now.
    /// The first and last month's ranges are clamped to the enrollment date resp. the current time.
    private func months(since enrollmentDate: Date) -> [StatsMonth] {
        let cal = Calendar.current
        let now = Date()
        guard enrollmentDate < now else {
            return []
        }
        let firstMonthStart = cal.startOfMonth(for: enrollmentDate)
        return cal
            .dates(
                byAdding: .month,
                value: 1,
                startingAt: firstMonthStart,
                in: firstMonthStart..<cal.startOfNextMonth(for: now)
            )
            // NOTE: the sequence returned by `Calendar.dates(byAdding:)` begins at `start` + 1 interval,
            // i.e. it never yields the start date itself; hence the explicit prepending.
            .chaining(after: CollectionOfOne(firstMonthStart))
            .compactMap { monthStart in
                let components = cal.dateComponents([.year, .month], from: monthStart)
                guard let year = components.year, let month = components.month else {
                    return nil
                }
                let lowerBound = max(monthStart, enrollmentDate)
                let upperBound = min(cal.startOfNextMonth(for: monthStart), now)
                guard lowerBound < upperBound else {
                    return nil
                }
                return StatsMonth(
                    year: year,
                    monthString: String(format: "%02d", month),
                    range: lowerBound..<upperBound
                )
            }
    }

    private func writeStatsDocument<Entry: Codable>(
        accountDoc: DocumentReference,
        metricId: MetricID,
        month: StatsMonth,
        entriesKey: MonthlyStatsDocumentEntriesKey,
        entries: [Entry]
    ) async throws {
        guard !entries.isEmpty else {
            // don't touch the doc for months without any data: an empty query result can also mean that
            // HealthKit read authorization was revoked, and we don't want that to wipe existing entries
            return
        }
        // NOTE: writing to this document will mean that we implicitly end up creating an empty document
        // at `users/{uid}/stats/{metricId}`, which won't be queryable (bc it's empty).
        // this isn't a problem, as we currently don't need to query these docs, but we should at least
        // be aware of this being a thing.
        let doc = accountDoc
            .collection("stats")
            .document(metricId.rawValue)
            .collection("months")
            .document(month.documentId)
        do {
            // we first try to update the doc in place.
            // (the explicit cast forces the FirestoreUtils overload, which pre-encodes the entries;
            // the plain Firestore updateData cannot handle Swift structs)
            try await doc.updateData([
                FieldPath([entriesKey.rawValue, DataSourceID.healthKit.rawValue]): entries
            ] as [AnyHashable: any Codable])
        } catch let error as NSError where error.code == FirestoreErrorCode.notFound.rawValue {
            // the document we're tryng to update doesn't exist yet, so we need to create it
            let statsDoc = MonthlyStatsDocument(
                metric: metricId,
                entriesKey: entriesKey,
                entriesBySourceId: [.healthKit: entries]
            )
            try await doc.setData(from: statsDoc)
        }
    }
}


// MARK: Bucketed quantity metrics (hourly/daily sums resp. min/max/avg)

extension HealthKitStatsCalculator {
    private enum AggregationMode {
        case sum
        case minMaxAvg
    }

    private struct StatsRunDescriptor {
        let sampleType: SampleType<HKQuantitySample>
        /// the metric's well-known identifier per the data spec; used for the stats doc path and `metric` field. deliberately not the HK identifier.
        let metricId: MetricID
        let mode: AggregationMode
        let aggregationInterval: HealthKit.AggregationInterval
        let entriesKey: MonthlyStatsDocumentEntriesKey
        private(set) var timeRange: HealthKitQueryTimeRange

        func withTimeRange(_ newTimeRange: HealthKitQueryTimeRange) -> Self {
            var copy = self
            copy.timeRange = newTimeRange
            return copy
        }
    }
    
    
    // one run per metric in the spec's Metrics table (docs/MHCDataSpec.md)
    private static let bucketedDescriptors: [StatsRunDescriptor] = [
        .init(
            sampleType: .stepCount,
            metricId: .steps,
            mode: .sum,
            aggregationInterval: .hour,
            entriesKey: .hourly,
            timeRange: .currentMonth
        ),
        .init(
            sampleType: .appleExerciseTime,
            metricId: .exerciseTime,
            mode: .sum,
            aggregationInterval: .hour,
            entriesKey: .hourly,
            timeRange: .currentMonth
        ),
        .init(
            sampleType: .heartRate,
            metricId: .heartRate,
            mode: .minMaxAvg,
            aggregationInterval: .hour,
            entriesKey: .hourly,
            timeRange: .currentMonth
        )
    ]
    
    private static let individualSamplesDescriptors: [IndividualSamplesRunDescriptor] = [
        .init(sampleType: .bodyMass, metricId: .weight),
        .init(sampleType: .height, metricId: .height),
        .init(sampleType: .bodyMassIndex, metricId: .bmi)
    ]

    @concurrent
    private func runBucketedQuantityStats(_ descriptor: StatsRunDescriptor, months: [StatsMonth], accountDoc: DocumentReference) async throws {
        for month in months {
            self.logger.notice("Computing stats for stats/\(descriptor.metricId)/months/\(month.documentId)")
            if let stats = try? await self.calculateStats(for: descriptor.withTimeRange(.init(month.range))) {
                try await writeStatsDocument(
                    accountDoc: accountDoc,
                    metricId: descriptor.metricId,
                    month: month,
                    entriesKey: descriptor.entriesKey,
                    entries: stats
                )
            }
        }
    }

    @concurrent
    private func calculateStats(for input: StatsRunDescriptor) async throws -> [StatEntry] {
        let unit = input.sampleType.canonicalUnit
        switch input.mode {
        case .sum:
            let stats = try await healthKit.statisticsQuery(
                input.sampleType,
                aggregatedBy: [.sum],
                over: input.aggregationInterval,
                timeRange: input.timeRange
            )
            return stats.compactMap { stats in
                guard let sum = stats.sumQuantity() else {
                    return nil
                }
                return StatEntry(
                    start: stats.startDate,
                    end: stats.endDate,
                    unit: unit,
                    values: .sum(sum.doubleValue(for: unit))
                )
            }
        case .minMaxAvg:
            let stats = try await healthKit.statisticsQuery(
                input.sampleType,
                aggregatedBy: [.min, .max, .average],
                over: input.aggregationInterval,
                timeRange: input.timeRange
            )
            return stats.compactMap { stats in
                guard let min = stats.minimumQuantity(),
                      let max = stats.maximumQuantity(),
                      let avg = stats.averageQuantity() else {
                    return nil
                }
                return StatEntry(
                    start: stats.startDate,
                    end: stats.endDate,
                    unit: unit,
                    values: .minMaxAvg(
                        min: min.doubleValue(for: unit),
                        max: max.doubleValue(for: unit),
                        avg: avg.doubleValue(for: unit)
                    )
                )
            }
        }
    }
}


// MARK: Sleep (per-session time asleep)

extension HealthKitStatsCalculator {
    @concurrent
    private func runSleepStats(months: [StatsMonth], accountDoc: DocumentReference) async throws {
        for month in months {
            self.logger.notice("Computing stats for stats/sleep/months/\(month.documentId)")
            let samples: [HKCategorySample]
            do {
                // query with a ±1 day margin: sleep sessions typically span midnight, and the underlying HK
                // predicate only matches samples that both start AND end inside the range, which would
                // otherwise drop the sessions at the month boundaries
                let paddedRange = month.range.lowerBound.addingTimeInterval(-86400)..<month.range.upperBound.addingTimeInterval(86400)
                samples = try await healthKit.query(
                    .sleepAnalysis,
                    timeRange: .init(paddedRange),
                    source: CVHScore.sleepDataSourceFilter
                )
            } catch {
                self.logger.notice("ERROR: \(error)")
                continue
            }
            // group the samples into sleep sessions, and keep the sessions belonging to this month.
            // this matches how the dashboard used to turn sleep samples into the values it displays;
            // in particular, `totalTimeSpentAsleep` accounts for overlapping samples (e.g. from a phone and a watch
            // both tracking the same night), which we'd otherwise be double-counting.
            let sessions = try samples.splitIntoSleepSessions().filter { session in
                month.range.contains(session.timeRange.middle)
            }
            let entries = sessions.map { session in
                StatEntry(
                    start: session.startDate,
                    end: session.endDate,
                    unit: .hour(),
                    values: .sum(session.totalTimeSpentAsleep / 60 / 60)
                )
            }
            try await writeStatsDocument(
                accountDoc: accountDoc,
                metricId: .sleep,
                month: month,
                entriesKey: .sessions,
                entries: entries
            )
        }
    }
}


// MARK: Individual-samples metrics (weight/height/bmi, blood pressure)

extension HealthKitStatsCalculator {
    private struct IndividualSamplesRunDescriptor {
        let sampleType: SampleType<HKQuantitySample>
        /// the metric's well-known identifier per the data spec; used for the stats doc path and `metric` field. deliberately not the HK identifier.
        let metricId: MetricID
    }

    @concurrent
    private func runIndividualQuantitySampleStats(
        _ descriptor: IndividualSamplesRunDescriptor,
        months: [StatsMonth],
        accountDoc: DocumentReference
    ) async throws {
        let unit = descriptor.sampleType.canonicalUnit
        for month in months {
            self.logger.notice("Computing stats for stats/\(descriptor.metricId)/months/\(month.documentId)")
            let samples: [HKQuantitySample]
            do {
                samples = try await healthKit.query(descriptor.sampleType, timeRange: .init(month.range))
            } catch {
                self.logger.notice("ERROR: \(error)")
                continue
            }
            let entries = samples.map { sample in
                QuantitySampleEntry(date: sample.startDate, unit: unit, value: sample.quantity.doubleValue(for: unit))
            }
            try await writeStatsDocument(
                accountDoc: accountDoc,
                metricId: descriptor.metricId,
                month: month,
                entriesKey: .samples,
                entries: entries
            )
        }
    }

    @concurrent
    private func runBloodPressureStats(months: [StatsMonth], accountDoc: DocumentReference) async throws {
        let unit = SampleType.bloodPressureSystolic.canonicalUnit // mmHg
        for month in months {
            self.logger.notice("Computing stats for stats/blood-pressure/months/\(month.documentId)")
            let correlations: [HKCorrelation]
            do {
                correlations = try await healthKit.query(.bloodPressure, timeRange: .init(month.range))
            } catch {
                self.logger.notice("ERROR: \(error)")
                continue
            }
            let entries = correlations.compactMap { correlation -> BloodPressureSampleEntry? in
                guard let systolic = correlation.objects(for: SampleType.bloodPressureSystolic.hkSampleType).first as? HKQuantitySample,
                      let diastolic = correlation.objects(for: SampleType.bloodPressureDiastolic.hkSampleType).first as? HKQuantitySample else {
                    return nil
                }
                return BloodPressureSampleEntry(
                    date: correlation.startDate,
                    unit: unit,
                    systolic: systolic.quantity.doubleValue(for: unit),
                    diastolic: diastolic.quantity.doubleValue(for: unit)
                )
            }
            try await writeStatsDocument(
                accountDoc: accountDoc,
                metricId: .bloodPressure,
                month: month,
                entriesKey: .samples,
                entries: entries
            )
        }
    }
}


// MARK: Wire format

extension HealthKitStatsCalculator {
    fileprivate enum StatsWireFormat {
        /// spec: all timestamps in stats documents are ISO8601 strings; we include the device's local-time UTC offset (matching the bucket boundaries, which are computed in local time).
        /// - Note: the field modifiers must all be spelled out: calling any modifier on an `ISO8601FormatStyle` discards the default field set, so e.g. a bare `.timeZone(separator:)` style would format dates as just the offset.
        static let dateFormat = Date.ISO8601FormatStyle(timeZone: .current)
            .year().month().day() // swiftlint:disable:this multiline_function_chains
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: false)
            .timeZone(separator: .colon)

        static func parseDate(_ string: String) throws -> Date {
            if let date = try? Date(string, strategy: dateFormat) {
                return date
            }
            // tolerate other ISO8601 offset spellings (e.g. "Z", or no colon in the offset)
            return try Date(string, strategy: .iso8601)
        }
    }


    /// A single sum or min/max/avg entry in a bucketed (hourly/daily) single-month stats document
    fileprivate struct StatEntry: Codable {
        enum CodingKeys: String, Swift.CodingKey {
            case start, end, unit, sum, min, max, avg
        }

        enum StatsValues {
            case sum(Double)
            case minMaxAvg(min: Double, max: Double, avg: Double)

            init(from container: KeyedDecodingContainer<CodingKeys>) throws {
                if container.contains(.sum) {
                    self = .sum(try container.decode(Double.self, forKey: .sum))
                } else {
                    let min = try container.decode(Double.self, forKey: .min)
                    let max = try container.decode(Double.self, forKey: .max)
                    let avg = try container.decode(Double.self, forKey: .avg)
                    self = .minMaxAvg(min: min, max: max, avg: avg)
                }
            }

            func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
                switch self {
                case .sum(let sum):
                    try container.encode(sum, forKey: .sum)
                case let .minMaxAvg(min, max, avg):
                    try container.encode(min, forKey: .min)
                    try container.encode(max, forKey: .max)
                    try container.encode(avg, forKey: .avg)
                }
            }
        }

        let start: Date
        let end: Date
        let unit: HKUnit
        let values: StatsValues

        init(start: Date, end: Date, unit: HKUnit, values: StatsValues) {
            self.start = start
            self.end = end
            self.unit = unit
            self.values = values
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.start = try StatsWireFormat.parseDate(container.decode(String.self, forKey: .start))
            self.end = try StatsWireFormat.parseDate(container.decode(String.self, forKey: .end))
            self.unit = try container.decode(HKUnit.self, forKey: .unit)
            self.values = try .init(from: container)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(start.formatted(StatsWireFormat.dateFormat), forKey: .start)
            try container.encode(end.formatted(StatsWireFormat.dateFormat), forKey: .end)
            try container.encode(unit, forKey: .unit)
            try values.encode(to: &container)
        }
    }


    /// A single reading in an individual-samples single-month stats document
    fileprivate struct QuantitySampleEntry: Codable {
        enum CodingKeys: String, Swift.CodingKey {
            case date, unit, value
        }

        let date: Date
        let unit: HKUnit
        let value: Double

        init(date: Date, unit: HKUnit, value: Double) {
            self.date = date
            self.unit = unit
            self.value = value
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.date = try StatsWireFormat.parseDate(container.decode(String.self, forKey: .date))
            self.unit = try container.decode(HKUnit.self, forKey: .unit)
            self.value = try container.decode(Double.self, forKey: .value)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(date.formatted(StatsWireFormat.dateFormat), forKey: .date)
            try container.encode(unit, forKey: .unit)
            try container.encode(value, forKey: .value)
        }
    }


    /// A single sys/dia reading pair in the blood-pressure single-month stats document
    fileprivate struct BloodPressureSampleEntry: Codable {
        enum CodingKeys: String, Swift.CodingKey {
            case date, unit, systolic, diastolic
        }

        let date: Date
        let unit: HKUnit
        let systolic: Double
        let diastolic: Double

        init(date: Date, unit: HKUnit, systolic: Double, diastolic: Double) {
            self.date = date
            self.unit = unit
            self.systolic = systolic
            self.diastolic = diastolic
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.date = try StatsWireFormat.parseDate(container.decode(String.self, forKey: .date))
            self.unit = try container.decode(HKUnit.self, forKey: .unit)
            self.systolic = try container.decode(Double.self, forKey: .systolic)
            self.diastolic = try container.decode(Double.self, forKey: .diastolic)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(date.formatted(StatsWireFormat.dateFormat), forKey: .date)
            try container.encode(unit, forKey: .unit)
            try container.encode(systolic, forKey: .systolic)
            try container.encode(diastolic, forKey: .diastolic)
        }
    }
}


// MARK: Stats document

extension HealthKitStatsCalculator {
    fileprivate enum MonthlyStatsDocumentEntriesKey: String, CaseIterable {
        case hourly, daily, sessions, samples
    }

    fileprivate struct MonthlyStatsDocument<Entry: Codable>: Codable {
        private struct CodingKey: Swift.CodingKey {
            fileprivate static var version: Self { Self(stringValue: "version") }
            fileprivate static var metric: Self { Self(stringValue: "metric") }

            let stringValue: String
            var intValue: Int? { nil }

            init(stringValue: String) {
                self.stringValue = stringValue
            }
            init?(intValue: Int) {
                nil
            }
        }

        var version: Int
        var metric: MetricID
        var entriesKey: MonthlyStatsDocumentEntriesKey
        var entriesBySourceId: [DataSourceID: [Entry]]

        init(
            metric: MetricID,
            entriesKey: MonthlyStatsDocumentEntriesKey,
            entriesBySourceId: [DataSourceID: [Entry]]
        ) {
            self.version = 0
            self.metric = metric
            self.entriesKey = entriesKey
            self.entriesBySourceId = entriesBySourceId
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKey.self)
            version = try container.decode(Int.self, forKey: .version)
            metric = try container.decode(MetricID.self, forKey: .metric)
            let entriesByKey: [MonthlyStatsDocumentEntriesKey: [DataSourceID: [Entry]]] = try MonthlyStatsDocumentEntriesKey.allCases.reduce(
                into: [:]
            ) { result, entriesKey in
                if let entries = try container.decodeIfPresent(
                    [DataSourceID: [Entry]].self,
                    forKey: CodingKey(stringValue: entriesKey.rawValue)
                ) {
                    result[entriesKey] = entries
                }
            }
            guard let entry = entriesByKey.first else { // there should be at least one entry
                let allAllowedKeys = MonthlyStatsDocumentEntriesKey.allCases.map { "'\($0.rawValue)'" }.sorted()
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Expected exactly 1 entry; got none. (Expected one of \(allAllowedKeys))"
                ))
            }
            guard entriesByKey.count == 1 else { // and there should not be any additional entries
                let parsedEntryKeys = entriesByKey.keys.map { "'\($0.rawValue)'" }.sorted()
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Expected exactly 1 entry; got \(entriesByKey.count) (\(parsedEntryKeys))"
                ))
            }
            (entriesKey, entriesBySourceId) = entry
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKey.self)
            try container.encode(version, forKey: .version)
            try container.encode(metric, forKey: .metric)
            try container.encode(entriesBySourceId, forKey: .init(stringValue: entriesKey.rawValue))
        }
    }
}
