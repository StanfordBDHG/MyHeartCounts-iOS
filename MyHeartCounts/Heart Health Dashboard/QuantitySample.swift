//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftData
import struct SwiftUI.Color


enum MHCSampleType: Hashable, Identifiable, Sendable {
    case healthKit(SampleTypeProxy)
    case custom(CustomHealthSample.SampleType)
    
    var id: AnyHashable {
        switch self {
        case .healthKit(let sampleType):
            sampleType.id
        case .custom(let sampleType):
            sampleType.id
        }
    }
    
    var displayTitle: String {
        switch self {
        case .healthKit(let sampleType):
            sampleType.underlyingSampleType.displayTitle
        case .custom(let sampleType):
            sampleType.displayTitle
        }
    }
    
    var displayUnit: HKUnit? {
        asQuantityType?.displayUnit
    }
    
    var asQuantityType: MHCQuantitySampleType? {
        .init(self)
    }
}


struct CustomQuantitySampleType: Hashable, Identifiable, Sendable {
    let id: String
    let displayTitle: String
    let displayUnit: HKUnit
    let aggregationKind: StatisticsAggregationOption
    let preferredTintColor: Color
    
    init(id: String, displayTitle: String, displayUnit: HKUnit, aggregationKind: StatisticsAggregationOption, preferredTintColor: Color) {
        self.id = id
        self.displayTitle = displayTitle
        self.displayUnit = displayUnit
        self.aggregationKind = aggregationKind
        self.preferredTintColor = preferredTintColor
    }
    
    init?(_ sampleType: CustomHealthSample.SampleType) {
        switch sampleType {
        case .bloodLipids:
            self = Self(
                id: "mhc:custom:bloodLipids",
                displayTitle: sampleType.displayTitle,
                displayUnit: sampleType.displayUnit!, // swiftlint:disable:this force_unwrapping
                aggregationKind: .avg,
                preferredTintColor: .yellow // ???
            )
        case .nicotineExposure, .dietMEPAScore:
            return nil
        }
    }
}


enum MHCQuantitySampleType: Hashable, Identifiable, Sendable {
    case healthKit(SampleType<HKQuantitySample>)
    case custom(CustomQuantitySampleType)
    
    var id: String {
        switch self {
        case .healthKit(let sampleType):
            sampleType.id
        case .custom(let sampleType):
            sampleType.id
        }
    }
    
    var displayTitle: String {
        switch self {
        case .healthKit(let sampleType):
            sampleType.displayTitle
        case .custom(let sampleType):
            sampleType.displayTitle
        }
    }
    
    var displayUnit: HKUnit {
        switch self {
        case .healthKit(let sampleType):
            sampleType.displayUnit
        case .custom(let sampleType):
            sampleType.displayUnit
        }
    }
    
    init?(_ other: MHCSampleType) {
        switch other {
        case .healthKit(.quantity(let sampleType)):
            self = .healthKit(sampleType)
        case .healthKit, .custom:
            return nil
        }
    }
}


struct QuantitySample: Hashable, Identifiable, Sendable {
    typealias SampleType = MHCQuantitySampleType
    
    let id: UUID
    let sampleType: SampleType
    let unit: HKUnit
    let value: Double
    let startDate: Date
    let endDate: Date
    
    var timeRange: Range<Date> {
        startDate..<endDate
    }
    
    init(id: UUID, sampleType: SampleType, unit: HKUnit, value: Double, startDate: Date, endDate: Date) {
        self.id = id
        self.sampleType = sampleType
        self.unit = unit
        self.value = value
        self.startDate = startDate
        self.endDate = endDate
        checkDateRangeValid()
    }
    
    init(id: UUID, sampleType: SampleType, quantity: HKQuantity, startDate: Date, endDate: Date) {
        self.init(
            id: id,
            sampleType: sampleType,
            unit: sampleType.displayUnit,
            value: quantity.doubleValue(for: sampleType.displayUnit),
            startDate: startDate,
            endDate: endDate
        )
    }
    
    init(_ other: HKQuantitySample) {
        guard let sampleType = SpeziHealthKit.SampleType<HKQuantitySample>(HKQuantityTypeIdentifier(rawValue: other.quantityType.identifier)) else {
            preconditionFailure("Unable to obtain SampleType<HKQuantitySample> for HKQuantityType '\(other.quantityType.identifier)'")
        }
        self.init(
            id: other.uuid,
            sampleType: .healthKit(sampleType),
            quantity: other.quantity,
            startDate: other.startDate,
            endDate: other.endDate
        )
    }
    
    private func checkDateRangeValid() {
        precondition(endDate >= startDate)
    }
}


extension Collection where Element == QuantitySample {
    func aggregated(
        using kind: StatisticsAggregationOption,
        over timeInterval: HealthKitStatisticsQuery.AggregationInterval,
        anchor: Date,
        overallTimeRange: Range<Date>,
        calendar: Calendar
    ) -> [QuantitySample] {
        calendar
            .dates(
                byAdding: timeInterval.intervalComponents,
                startingAt: anchor,
                in: anchor..<overallTimeRange.upperBound
            )
            // `Calendar.dates(byAdding:startingAt:in:)` doesn't include the start date, so we need to manually prepend it to the sequence.
            .chaining(after: CollectionOfOne(anchor))
            .lazy
            .compactMap { date -> Range<Date>? in
                calendar.date(byAdding: timeInterval.intervalComponents, to: date).map { date..<$0 }
            }
            .flatMap { (range: Range<Date>) in
                print("range: \(range)")
                return self/*.lazy*/.filter { sample in
                    if sample.startDate == sample.endDate {
                        // if the sample represents a single point in time, we simply check whether the range contains that instant
                        range.contains(sample.startDate)
                    } else {
                        // otherwise (if the sample represents a time period), we check for overlap
                        range.overlaps(sample.timeRange)
                    }
                }
                .map { sample in
                    switch kind {
                    case .avg, .min, .max:
                        // for the non-cumulative options, we can simply pass the data on unchanged.
                        return sample
                    case .sum:
                        if sample.startDate == sample.endDate || (range.contains(sample.startDate) && range.contains(sample.endDate)) {
                            // if the sample is fully contained w/in the range, we pass it on unchanged
                            return sample
                        } else {
                            // otherwise, we determine how much of the sample falls into this time range, and return that
                            let overlapAmount = sample.endDate.timeIntervalSince(sample.startDate) / range.timeInterval
                            return QuantitySample(
                                id: sample.id,
                                sampleType: sample.sampleType,
                                unit: sample.unit,
                                value: sample.value * overlapAmount,
                                startDate: Swift.max(sample.startDate, range.lowerBound),
                                endDate: Swift.min(sample.endDate, range.upperBound)
                            )
                        }
                    }
                }
            }
    }
    
    
    func aggregated( // swiftlint:disable:this cyclomatic_complexity
        using input: HealthDashboardLayout.SingleValueConfig._Variant,
        overallTimeRange: Range<Date>,
        calendar: Calendar
    ) -> [QuantitySample] {
        guard let firstSample = first else {
            return []
        }
        let sampleType = firstSample.sampleType
        switch input {
        case .mostRecentSample:
            if let sample = self.max(by: \.endDate) {
                return [sample]
            } else {
                return []
            }
        case let .aggregated(steps, final):
            var samples = Array(self)
            for step in steps {
                samples = samples.aggregated(
                    using: step.kind,
                    over: step.interval,
                    anchor: calendar.startOfDay(for: overallTimeRange.lowerBound),
                    overallTimeRange: overallTimeRange,
                    calendar: calendar
                )
            }
            guard !samples.isEmpty else {
                return samples // de-facto unreachable, but we wanna be safe
            }
            guard let final else {
                return samples
            }
            return [
                QuantitySample(
                    id: UUID(), // ???
                    sampleType: sampleType,
                    unit: sampleType.displayUnit,
                    value: { () -> Double in
                        switch final {
                        case .sum:
                            samples.reduce(0) { $0 + $1.value }
                        case .avg:
                            samples.reduce(0) { $0 + $1.value } / Double(samples.count)
                        case .min:
                            // SAFETY: we know that samples is non-empty
                            samples.min(of: \.value)! // swiftlint:disable:this force_unwrapping
                        case .max:
                            // SAFETY: we know that samples is non-empty
                            samples.max(of: \.value)! // swiftlint:disable:this force_unwrapping
                        }
                    }(),
                    // SAFETY: we know that samples is non-empty
                    startDate: samples.min(of: \.startDate)!, // swiftlint:disable:this force_unwrapping
                    // SAFETY: we know that samples is non-empty
                    endDate: samples.max(of: \.endDate)! // swiftlint:disable:this force_unwrapping
                )
            ]
        }
    }
}


extension Range where Bound == Date {
    var timeInterval: TimeInterval {
        upperBound.timeIntervalSince(lowerBound)
    }
}
