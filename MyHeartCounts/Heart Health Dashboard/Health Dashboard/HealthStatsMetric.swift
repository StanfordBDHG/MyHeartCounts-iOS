//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import HealthKit
import MyHeartCountsShared
import SpeziHealthKit
import SpeziHealthKitUI


/// A metric for which the server-side stats documents exist (at `users/{uid}/stats/{metricId}/{year}/{month}`),
/// and which maps onto a HealthKit quantity sample type displayed in the Health Dashboard.
///
/// See `docs/MHCDataSpec.md` (§User Data Statistics / §Metrics) for the definition of the metrics and the documents' wire format;
/// the write side lives in ``HealthKitStatsCalculator``.
///
/// - Note: this intentionally only models the metrics that map onto `HKQuantitySample`-based dashboard tiles;
///     sleep and blood pressure also have stats documents, but are displayed via dedicated tiles that don't go through
///     the quantity-samples pipeline, and aren't (yet) covered by the stats-documents data source.
struct HealthStatsMetric: Hashable, Sendable {
    static let steps = Self(id: .steps, sampleType: .stepCount)
    static let exerciseTime = Self(id: .exerciseTime, sampleType: .appleExerciseTime)
    static let heartRate = Self(id: .heartRate, sampleType: .heartRate)
    static let weight = Self(id: .weight, sampleType: .bodyMass)
    static let height = Self(id: .height, sampleType: .height)
    static let bmi = Self(id: .bmi, sampleType: .bodyMassIndex)
    
    static let all: [Self] = [.steps, .exerciseTime, .heartRate, .weight, .height, .bmi]
    
    /// The metric's well-known identifier, as used in the stats document paths and the documents' `metric` field.
    let id: HealthKitStatsCalculator.MetricID
    /// The quantity sample type this metric corresponds to.
    let sampleType: SampleType<HKQuantitySample>
    
    private init(id: HealthKitStatsCalculator.MetricID, sampleType: SampleType<HKQuantitySample>) {
        self.id = id
        self.sampleType = sampleType
    }
    
    /// The metric corresponding to a quantity sample type, if one exists.
    init?(_ sampleType: SampleType<HKQuantitySample>) {
        if let metric = Self.all.first(where: { $0.sampleType.id == sampleType.id }) {
            self = metric
        } else {
            return nil
        }
    }
}


/// A single sleep session from the `sleep` metric's stats documents.
struct SleepSessionStatsSample: Hashable, Sendable {
    /// the session's bounds
    let timeRange: Range<Date>
    /// the time spent asleep during the session, in hours
    let hoursAsleep: Double
}


/// A single blood pressure reading from the `blood-pressure` metric's stats documents.
struct BloodPressureStatsSample: Hashable, Sendable {
    let date: Date
    let systolic: Double
    let diastolic: Double
    
    var timeRange: Range<Date> {
        date..<date
    }
}


// MARK: Interval Reduction

extension Collection where Element == QuantitySample {
    /// Reduces the samples into one sample per aggregation interval, mirroring the shape an `HKStatisticsQuery` produces.
    ///
    /// Used by the stats-documents data source, whose raw entries are at the resolution stored in the stats documents
    /// (e.g., hourly buckets), and need to be reduced into the interval requested by e.g. a chart.
    ///
    /// - Note: reducing already-aggregated buckets is an approximation where the requested interval doesn't align with
    ///     the stored buckets: sums are attributed proportionally, and an interval's `avg` is the unweighted mean of the
    ///     overlapping buckets' averages. Also, the achievable resolution is limited by the stored bucket size
    ///     (requesting a finer interval simply yields the overlapping bucket's value for each sub-interval).
    func reducedIntoIntervals(
        using kind: StatisticsAggregationOption,
        over timeInterval: HealthKitStatisticsQuery.AggregationInterval,
        anchor: Date,
        overallTimeRange: Range<Date>,
        calendar: Calendar
    ) -> [QuantitySample] {
        guard let sampleType = self.first?.sampleType else {
            return []
        }
        // if the requested interval is finer than the resolution of the (already-bucketed) input samples,
        // subdividing would just repeat each stored bucket's value for every sub-interval it overlaps
        // (including sub-intervals that had no actual data); in that case we instead pass the stored buckets
        // through unchanged. (the achievable resolution is inherently limited by what the stats documents store.)
        if let requestedInterval = calendar.date(byAdding: timeInterval.intervalComponents, to: anchor)?.timeIntervalSince(anchor),
           self.contains(where: { $0.timeRange.timeInterval > requestedInterval }) {
            return self.sorted(using: KeyPathComparator(\.startDate))
        }
        let unit = sampleType.canonicalUnit
        return calendar
            .dates(
                byAdding: timeInterval.intervalComponents,
                startingAt: anchor,
                in: anchor..<overallTimeRange.upperBound
            )
            // `Calendar.dates(byAdding:startingAt:in:)` doesn't include the start date, so we need to manually prepend it to the sequence.
            .chaining(after: CollectionOfOne(anchor))
            .compactMap { date -> Range<Date>? in
                calendar.date(byAdding: timeInterval.intervalComponents, to: date).map { date..<$0 }
            }
            .compactMap { (range: Range<Date>) -> QuantitySample? in
                let overlapping = self.filter { sample in
                    if sample.startDate == sample.endDate {
                        range.contains(sample.startDate)
                    } else {
                        range.overlaps(sample.timeRange)
                    }
                }
                guard !overlapping.isEmpty else {
                    return nil
                }
                return QuantitySample(
                    id: UUID(),
                    sampleType: sampleType,
                    unit: unit,
                    value: overlapping.reducedValue(using: kind, in: range, unit: unit),
                    startDate: range.lowerBound,
                    endDate: range.upperBound
                )
            }
    }
    
    /// Reduces the (non-empty) collection of samples overlapping `range` into a single value.
    private func reducedValue(using kind: StatisticsAggregationOption, in range: Range<Date>, unit: HKUnit) -> Double {
        switch kind {
        case .sum:
            reduce(0) { acc, sample in
                if sample.startDate == sample.endDate || (range.contains(sample.startDate) && sample.endDate <= range.upperBound) {
                    return acc + sample.value(as: unit)
                } else {
                    // the sample only partially overlaps the interval; attribute it proportionally
                    let overlap = Swift.max(sample.startDate, range.lowerBound)..<Swift.min(sample.endDate, range.upperBound)
                    let overlapAmount = overlap.timeInterval / sample.timeRange.timeInterval
                    return acc + sample.value(as: unit) * overlapAmount
                }
            }
        case .avg:
            reduce(0) { $0 + $1.value(as: unit) } / Double(count)
        case .min:
            // SAFETY: the caller guarantees that the collection is non-empty
            self.lazy.map { $0.value(as: unit) }.min()! // swiftlint:disable:this force_unwrapping
        case .max:
            // SAFETY: the caller guarantees that the collection is non-empty
            self.lazy.map { $0.value(as: unit) }.max()! // swiftlint:disable:this force_unwrapping
        }
    }
}
