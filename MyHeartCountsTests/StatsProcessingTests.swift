//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
@testable import MyHeartCounts
import SpeziHealthKit
import SpeziHealthKitUI
import Testing


@Suite
struct StatsProcessingTests {
    private let healthKit = "com.apple.HealthKit"
    private var range: Range<Date> { date(0)..<date(24) }

    @Test
    func cumulativeBucketsFillGapsWithoutAddingOverlaps() throws {
        let documents = [
            document(.steps, [healthKit: [bucket(0, amount: 100, unit: "count")]]),
            document(.steps, ["wearable": [bucket(0, amount: 900, unit: "count"), bucket(1, amount: 200, unit: "count")]])
        ]
        let result = try StatsStore.Processor.quantity(
            documents: documents,
            metric: .steps,
            timeRange: range,
            aggregationKind: .sum
        )
        #expect(result.elements.map { $0.value(as: .count()) } == [100, 200])
        #expect(result.contributingSourceIDs == [healthKit, "wearable"])
        #expect(result.diagnostics.count == 1)
    }

    @Test
    func explicitPoliciesSelectAndFillDeterministically() throws {
        let sources = [healthKit: [bucket(0, amount: 100, unit: "count")], "wearable": [bucket(1, amount: 200, unit: "count")]]
        let only = try StatsStore.Processor.quantity(
            documents: [document(.steps, sources)],
            metric: .steps,
            timeRange: range,
            aggregationKind: .sum,
            sourcePolicy: .only("wearable")
        )
        #expect(only.elements.map { $0.value(as: .count()) } == [200])
        let preferred = try StatsStore.Processor.quantity(
            documents: [document(.steps, sources)],
            metric: .steps,
            timeRange: range,
            aggregationKind: .sum,
            sourcePolicy: .preferred(["wearable"])
        )
        #expect(preferred.elements.map { $0.value(as: .count()) } == [100, 200])
        let ties = document(.steps, ["z": [bucket(0, amount: 300, unit: "count")], "a": [bucket(0, amount: 50, unit: "count")]])
        let deterministic = try StatsStore.Processor.quantity(
            documents: [ties],
            metric: .steps,
            timeRange: range,
            aggregationKind: .sum
        )
        #expect(deterministic.elements.first?.value(as: .count()) == 50)
    }

    @Test
    func strictPolicyRejectsCompetingCumulativeTotals() {
        let sources = [healthKit: [bucket(0, amount: 100, unit: "count")], "wearable": [bucket(0, amount: 200, unit: "count")]]
        #expect(throws: StatsStore.Processor.Error.self) {
            try StatsStore.Processor.quantity(
                documents: [document(.steps, sources)],
                metric: .steps,
                timeRange: range,
                aggregationKind: .sum,
                sourcePolicy: .mergeCompatible
            )
        }
    }

    @Test
    func heartRateExtremaMergeWithoutRequiringIndependentOrigins() throws {
        let sources = [healthKit: [bucket(0, amount: 70)], "wearable": [bucket(0, amount: 90)]]
        let minimum = try StatsStore.Processor.quantity(
            documents: [document(.heartRate, sources)],
            metric: .heartRate,
            timeRange: range,
            aggregationKind: .min
        )
        let maximum = try StatsStore.Processor.quantity(
            documents: [document(.heartRate, sources)],
            metric: .heartRate,
            timeRange: range,
            aggregationKind: .max
        )
        #expect(minimum.elements.first?.value(as: HKUnit.count().unitDivided(by: .minute())) == 70)
        #expect(maximum.elements.first?.value(as: HKUnit.count().unitDivided(by: .minute())) == 90)
        #expect(maximum.contributingSourceIDs == [healthKit, "wearable"])
    }

    @Test
    func weightedAveragesCannotMergeSharedOriginsOrDifferentAlgorithms() {
        let first = weightedBucket(0, amount: 60, weight: 1, origin: "A")
        var differentAlgorithm = weightedBucket(0, amount: 90, weight: 3, origin: "B")
        differentAlgorithm.average = StatsDocument.Average(numerator: 270, denominator: 3, weighting: "other")
        for second in [weightedBucket(0, amount: 90, weight: 3, origin: "A"), differentAlgorithm, bucket(0, amount: 90)] {
            #expect(throws: StatsStore.Processor.Error.self) {
                try StatsStore.Processor.quantity(
                    documents: [document(.heartRate, [healthKit: [first], "wearable": [second]])],
                    metric: .heartRate,
                    timeRange: range,
                    aggregationKind: .avg,
                    sourcePolicy: .mergeCompatible
                )
            }
        }
    }

    @Test
    func partiallyOverlappingBucketsAndQueryBoundsDoNotMergeExtrema() throws {
        let sources = [healthKit: [bucket(0, amount: 60)], "wearable": [bucket(0.5, amount: 90)]]
        let result = try StatsStore.Processor.quantity(
            documents: [document(.heartRate, sources)],
            metric: .heartRate,
            timeRange: range,
            aggregationKind: .max
        )
        #expect(result.elements.count == 1)
        #expect(result.contributingSourceIDs == [healthKit])
        let partial = try StatsStore.Processor.quantity(
            documents: [document(.heartRate, [healthKit: [bucket(0, amount: 60)], "wearable": [bucket(0, amount: 90)]])],
            metric: .heartRate,
            timeRange: date(0.5)..<date(1),
            aggregationKind: .max
        )
        #expect(partial.contributingSourceIDs == [healthKit])
        #expect(partial.diagnostics.contains(.partialBucket(timeRange: date(0)..<date(1))))
    }

    @Test
    func observationsFillGapsAndDeduplicateStableIdentity() throws {
        let first = observation(0, amount: 70, origin: "A", identity: "original:1")
        let second = observation(1, amount: 80, origin: "B", identity: "original:2")
        let result = try StatsStore.Processor.quantity(
            documents: [document(.weight, [healthKit: [first], "wearable": [first, second]])],
            metric: .weight,
            timeRange: range,
            aggregationKind: .avg,
            sourcePolicy: .mergeCompatible
        )
        #expect(result.elements.map { $0.value(as: .gramUnit(with: .kilo)) } == [70, 80])
        #expect(result.diagnostics.isEmpty)
        let unknown = try StatsStore.Processor.quantity(
            documents: [document(.weight, [healthKit: [first], "wearable": [observation(0, amount: 90), observation(1, amount: 80)]])],
            metric: .weight,
            timeRange: range,
            aggregationKind: .avg
        )
        #expect(unknown.elements.map { $0.value(as: .gramUnit(with: .kilo)) } == [70, 80])
        #expect(unknown.diagnostics.count == 1)
    }

    @Test
    func sleepOverlapsPreferOneSessionAndFillUncoveredSessions() throws {
        let sources = [
            healthKit: [bucket(0, amount: 0.5, unit: "hr")],
            "wearable": [bucket(0, amount: 0.75, unit: "hr"), bucket(2, amount: 1, unit: "hr")]
        ]
        let result = try StatsStore.Processor.sleepSessions(documents: [StatsDocument(metric: "sleep", entriesBySourceId: sources)], timeRange: range)
        #expect(result.elements.map(\.hoursAsleep) == [0.5, 1])
        #expect(result.contributingSourceIDs == [healthKit, "wearable"])
    }

    @Test
    func bloodPressureValidatesAndConvertsUnits() throws {
        var valid = StatsDocument.Entry(unit: "mmHg")
        valid.date = date(0).ISO8601Format()
        valid.systolic = 120
        valid.diastolic = 80
        var invalid = StatsDocument.Entry(unit: "kg")
        invalid.date = date(1).ISO8601Format()
        invalid.systolic = 120
        invalid.diastolic = 80
        let result = try StatsStore.Processor.bloodPressure(
            documents: [StatsDocument(metric: "blood-pressure", entriesBySourceId: [healthKit: [valid, invalid]])], timeRange: range
        )
        #expect(result.elements == [BloodPressureStatsSample(date: date(0), systolic: 120, diastolic: 80)])
        #expect(result.diagnostics == [.malformedEntryCount(1)])
    }

    @Test
    func malformedEntriesDoNotDiscardValidMonthData() throws {
        let json = """
        {"version":0,"metric":"steps","hourly":{"com.apple.HealthKit":[
          {"start":"1970-01-01T00:00:00Z","end":"1970-01-01T01:00:00Z","sum":100,"unit":"count"},
          {"start":"not a date","sum":200,"unit":"count"},
          {"start":"1970-01-01T00:00:00Z","sum":"invalid","unit":"count"}
        ]}}
        """
        let document = try JSONDecoder().decode(StatsDocument.self, from: Data(json.utf8))
        let result = try StatsStore.Processor.quantity(
            documents: [document],
            metric: .steps,
            timeRange: range,
            aggregationKind: .sum
        )
        #expect(result.elements.count == 1)
        #expect(result.diagnostics == [.malformedEntryCount(2)])
    }

    @Test
    func mismatchedMetricsAndUnsupportedVersionsAreDiagnosed() throws {
        let invalid = StatsDocument(version: 9, metric: "steps", entriesBySourceId: [healthKit: [bucket(0, amount: 100, unit: "count")]])
        let result = try StatsStore.Processor.quantity(
            documents: [invalid, document(.heartRate, [:])],
            metric: .steps,
            timeRange: range,
            aggregationKind: .sum
        )
        #expect(result.elements.isEmpty)
        #expect(result.diagnostics == [.invalidDocumentCount(2)])
    }
}


extension StatsProcessingTests {
    @Test
    func unknownProvenanceOnlyConflictsAtTheSameInstant() throws {
        let first = observation(0, amount: 70, identity: "original:1")
        var copy = first
        copy.date = date(2).ISO8601Format()
        let result = try StatsStore.Processor.quantity(
            documents: [document(.weight, [healthKit: [first], "wearable": [observation(1, amount: 80), copy]])],
            metric: .weight,
            timeRange: range,
            aggregationKind: .avg,
            sourcePolicy: .mergeCompatible
        )
        #expect(result.elements.map { $0.value(as: .gramUnit(with: .kilo)) } == [70, 80])
        #expect(result.diagnostics.isEmpty)
        #expect(throws: StatsStore.Processor.Error.self) {
            try StatsStore.Processor.quantity(
                documents: [document(.weight, [healthKit: [first], "wearable": [observation(0, amount: 80)]])],
                metric: .weight,
                timeRange: range,
                aggregationKind: .avg,
                sourcePolicy: .mergeCompatible
            )
        }
    }

    @Test
    func preferredObservationsSelectAtEachTimestampAndRetainIndependentReadings() throws {
        let sources = [
            healthKit: [observation(0, amount: 70, origin: "A")],
            "wearable": [observation(0, amount: 80, origin: "B"), observation(1, amount: 90, origin: "B")]
        ]
        let result = try StatsStore.Processor.quantity(
            documents: [document(.weight, sources)],
            metric: .weight,
            timeRange: range,
            aggregationKind: .avg,
            sourcePolicy: .preferred([healthKit])
        )
        #expect(result.elements.map { $0.value(as: .gramUnit(with: .kilo)) } == [70, 90])
        #expect(result.contributingSourceIDs == [healthKit, "wearable"])
        #expect(result.diagnostics.count == 1)
    }

    @Test
    func missingOrAmbiguousDocumentEntryContainersAreRejected() {
        for json in [#"{"version":0,"metric":"steps"}"#, #"{"version":0,"metric":"steps","hourly":{},"daily":{}}"#] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(StatsDocument.self, from: Data(json.utf8))
            }
        }
    }

    @Test
    func invalidWeightsCannotEnableSourceMerging() {
        let first = weightedBucket(0, amount: 60, weight: 1, origin: "A")
        for average in [
            StatsDocument.Average(numerator: 270, denominator: 0, weighting: "test.temporal.v1"),
            StatsDocument.Average(numerator: 200, denominator: 3, weighting: "test.temporal.v1")
        ] {
            var second = weightedBucket(0, amount: 90, weight: 3, origin: "B")
            second.average = average
            #expect(throws: StatsStore.Processor.Error.self) {
                try StatsStore.Processor.quantity(
                    documents: [document(.heartRate, [healthKit: [first], "wearable": [second]])],
                    metric: .heartRate,
                    timeRange: range,
                    aggregationKind: .avg,
                    sourcePolicy: .mergeCompatible
                )
            }
        }
    }

    @Test
    func emptyRangesAndExclusiveUpperBoundsReturnNoObservations() throws {
        let documents = [document(.weight, [healthKit: [observation(1, amount: 80)]])]
        for range in [date(0)..<date(1), date(1)..<date(1)] {
            let result = try StatsStore.Processor.quantity(
                documents: documents,
                metric: .weight,
                timeRange: range,
                aggregationKind: .avg
            )
            #expect(result.elements.isEmpty)
        }
        let emptyBuckets = try StatsStore.Processor.quantity(
            documents: [document(.steps, [healthKit: [bucket(0, amount: 100, unit: "count")]])],
            metric: .steps,
            timeRange: date(0.5)..<date(0.5),
            aggregationKind: .sum
        )
        #expect(emptyBuckets.elements.isEmpty)
    }
}


extension StatsProcessingTests {
    private func date(_ hour: Double) -> Date {
        Date(timeIntervalSince1970: hour * 3600)
    }

    private func document(_ metric: HealthStatsMetric, _ sources: [String: [StatsDocument.Entry]]) -> StatsDocument {
        StatsDocument(metric: metric.id.rawValue, entriesBySourceId: sources)
    }

    private func bucket(_ hour: Double, amount: Double, unit: String = "count/min") -> StatsDocument.Entry {
        var entry = StatsDocument.Entry(unit: unit)
        entry.start = date(hour).ISO8601Format()
        entry.end = date(hour + 1).ISO8601Format()
        entry.sum = amount
        entry.min = amount
        entry.max = amount
        entry.avg = amount
        return entry
    }

    private func weightedBucket(_ hour: Double, amount: Double, weight: Double, origin: String) -> StatsDocument.Entry {
        var entry = bucket(hour, amount: amount)
        entry.average = StatsDocument.Average(numerator: amount * weight, denominator: weight, weighting: "test.temporal.v1")
        entry.provenance = StatsDocument.Provenance(origins: [origin], observationID: nil)
        return entry
    }

    private func observation(_ hour: Double, amount: Double, origin: String? = nil, identity: String? = nil) -> StatsDocument.Entry {
        var entry = StatsDocument.Entry(unit: "kg")
        entry.date = date(hour).ISO8601Format()
        entry.value = amount
        entry.provenance = StatsDocument.Provenance(origins: origin.map { [$0] } ?? [], observationID: identity)
        return entry
    }

    private func interval(_ interval: HealthKitStatisticsQuery.AggregationInterval) -> StatsStore.AggregationInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return StatsStore.AggregationInterval(interval: interval, anchor: date(0), calendar: calendar)
    }
}
