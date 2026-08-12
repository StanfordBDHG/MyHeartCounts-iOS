//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import FirebaseFirestore
import Foundation
import Spezi
import SpeziAccount
import SpeziHealthKit
import SpeziFoundation
import SpeziFirestore
import OSLog


@Observable
final class HealthKitStatsCalculator: ServiceModule, EnvironmentAccessible, @unchecked Sendable {
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(Account.self) private var account
    
    func run() async {
        guard let accountId = await account.details?.accountId else {
            logger.error("no accountId")
            return
        }
        let accountDoc = FirebaseFirestore.Firestore.firestore().document("/users/\(accountId)")
        let descriptors: [StatsRunDescriptor] = [
            .init(sampleType: .stepCount, mode: .sum, aggregationInterval: .hour, timeRange: .currentMonth),
            .init(sampleType: .heartRate, mode: .minMaxAvg, aggregationInterval: .hour, timeRange: .currentMonth)
        ]
        logger.notice("starting")
        await withDiscardingTaskGroup { taskGroup in // TODO parallalise over just sample type or also over months?
            for descriptor in descriptors {
                taskGroup.addTask {
                    do {
                        try await self._run(descriptor, lastNMonths: 1, accountDoc: accountDoc)
                    } catch {
                        self.logger.notice("ERROR: \(error)")
                    }
                }
            }
        }
    }
    
    
    @concurrent
    private func _run(_ descriptor: StatsRunDescriptor, lastNMonths numMonths: Int, accountDoc: DocumentReference) async throws {
        let cal = Calendar.current
        let now = Date()
        let startDate = cal.date(byAdding: .month, value: -numMonths, to: cal.startOfMonth(for: now))!
        let months: some Sequence<Range<Date>> = cal
            .dates(byAdding: .month, value: 1, startingAt: startDate, in: startDate..<cal.startOfNextMonth(for: now))
            .lazy
            .map { $0..<cal.startOfNextMonth(for: $0) }
        for monthRange in months {
            logger.notice("\(descriptor.sampleType.id) \(monthRange)")
            let components = cal.dateComponents([.year, .month], from: monthRange.lowerBound)
            guard let year = components.year, let month = components.month else {
                self.logger.notice("hmmm \(components)")
                continue
            }
            let monthString = String(format: "%02d", month)
            self.logger.notice("Computing stats for stats/\(descriptor.sampleType.id)/\(year)/\(monthString)")
            if let stats = try? await self.calculateStats(for: descriptor.withTimeRange(.init(monthRange))) {
                let statsDoc = MonthlyStatsDocument(
                    metric: descriptor.sampleType.id,
                    statsTimeInterval: .hourly,
                    statsBySourceId: [
                        "com.apple.HealthKit": stats
                    ]
                )
                let doc = accountDoc
                    .collection("stats")
                    .document(descriptor.sampleType.id)
                    .collection(String(year))
                    .document(monthString)
                do {
                    // we first try to update the doc in place
                    try await doc.updateData([
                        FieldPath([statsDoc.statsTimeInterval.rawValue, "com.apple.HealthKit"]): stats
                    ])
                } catch let error as NSError where error.code == FirestoreErrorCode.notFound.rawValue {
                    // the document we're tryng to update doesn't exist yet, so we need to create it
                    try await doc.setData(from: statsDoc)
                }
            }
        }
    }
}

extension HealthKitStatsCalculator {
    private enum AggregationMode {
        case sum
        case minMaxAvg
    }
    
    private struct StatsRunDescriptor {
        let sampleType: SampleType<HKQuantitySample>
        let mode: AggregationMode
        let aggregationInterval: HealthKit.AggregationInterval
        private(set) var timeRange: HealthKitQueryTimeRange
        
        func withTimeRange(_ newTimeRange: HealthKitQueryTimeRange) -> Self {
            var copy = self
            copy.timeRange = newTimeRange
            return copy
        }
    }
    
    @concurrent
    private func calculateStats(for input: StatsRunDescriptor) async throws -> [MonthlyStatsDocument.StatEntry] {
        let unit = input.sampleType.displayUnit // TODO switch to canonicalUnit once #183 is merged
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
                return MonthlyStatsDocument.StatEntry(
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
                return MonthlyStatsDocument.StatEntry(
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


extension HealthKitStatsCalculator {
    fileprivate struct MonthlyStatsDocument: Codable {
        // A single sum or min/max/avg entry in the single-month stats document
        struct StatEntry: Codable {
            enum CodingKeys: String, Swift.CodingKey {
                case start, end, unit, sum, min, max, avg
            }
            
            enum StatsValues {
                case sum(Double)
                case minMaxAvg(min: Double, max: Double, avg: Double)
                
                init(from container: KeyedDecodingContainer<CodingKeys>) throws {
                    if let sum = try container.decodeIfPresent(Double.self, forKey: .sum) {
                        self = .sum(sum)
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
                self.start = try container.decode(Date.self, forKey: .start)
                self.end = try container.decode(Date.self, forKey: .end)
                self.unit = try container.decode(HKUnit.self, forKey: .unit)
                self.values = try .init(from: container)
            }
            
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(start, forKey: .start)
                try container.encode(end, forKey: .end)
                try container.encode(unit, forKey: .unit)
                try values.encode(to: &container)
            }
        }
        
        private struct CodingKey: Swift.CodingKey {
            fileprivate static let version = Self(stringValue: "version")
            fileprivate static let metric = Self(stringValue: "metric")
//            fileprivate static let statsIntervalHourly = Self(stringValue: "hourly")
//            fileprivate static let statsIntervalDaily = Self(stringValue: "daily")
            
            let stringValue: String
            var intValue: Int? { nil}
            
            init(stringValue: String) {
                self.stringValue = stringValue
            }
            init?(intValue: Int) {
                return nil
            }
        }
        
        
        enum StatsTimeInterval: String, CaseIterable {
            case hourly, daily
        }
        
        
        var version: Int
        var metric: String
        var statsTimeInterval: StatsTimeInterval
        var statsBySourceId: [String: [StatEntry]]
        
        init(
            metric: String,
            statsTimeInterval: StatsTimeInterval,
            statsBySourceId: [String: [StatEntry]]
        ) {
            self.version = 0
            self.metric = metric
            self.statsTimeInterval = statsTimeInterval
            self.statsBySourceId = statsBySourceId
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKey.self)
            version = try container.decode(Int.self, forKey: .version)
            metric = try container.decode(String.self, forKey: .metric)
            let hmmm: [StatsTimeInterval: [String: [StatEntry]]] = try StatsTimeInterval.allCases.reduce(into: [:]) { result, timeInterval in
                if let stats = try container.decodeIfPresent(
                    [String: [StatEntry]].self,
                    forKey: CodingKey(stringValue: timeInterval.rawValue)
                ) {
                    result[timeInterval] = stats
                }
            }
            guard hmmm.count == 1 else {
                fatalError() // TODO
            }
//            let entry = hmmm.first!
            (statsTimeInterval, statsBySourceId) = hmmm.first! // (entry.key, entry.value)
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKey.self)
            try container.encode(version, forKey: .version)
            try container.encode(metric, forKey: .metric)
            try container.encode(statsBySourceId, forKey: .init(stringValue: statsTimeInterval.rawValue))
        }
    }
}
