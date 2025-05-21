//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import HealthKit
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftData
import struct SwiftUI.Color



enum MHCSampleType: Hashable, Identifiable, Sendable {
    case healthKit(SampleTypeProxy)
    case custom(CustomHealthSample.SampleType) // TODO call this case swiftData instead?!
    
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
    let aggregationKind: StatisticsQueryAggregationKind
    let preferredTintColor: Color
}



enum MHCQuantitySampleType: Hashable, Identifiable, Sendable {
    case healthKit(SampleType<HKQuantitySample>)
    case custom(CustomQuantitySampleType)
    
    init?(_ other: MHCSampleType) {
        switch other {
        case .healthKit(.quantity(let sampleType)):
            self = .healthKit(sampleType)
        case .healthKit, .custom:
            return nil
        }
    }
    
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
        using kind: StatisticsQueryAggregationKind,
        over timeInterval: HealthKitStatisticsQuery.AggregationInterval,
        anchor: Date,
        overallTimeRange: Range<Date>,
        calendar: Calendar = .current
    ) -> [QuantitySample] {
        print(timeInterval.intervalComponents, overallTimeRange)
        var samplesAlreadyProcessed = Set<QuantitySample>()
        let retval = calendar
            .dates(
                byAdding: timeInterval.intervalComponents,
                startingAt: anchor,
                in: anchor..<overallTimeRange.upperBound
            )
            // `Calendar.dates(byAdding:startingAt:in:)` doesn't include the start date, so we need to manually prepend it to the sequence.
            .chaining(after: CollectionOfOne(anchor))
//            .lazy
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
                    if !samplesAlreadyProcessed.insert(sample).inserted {
                        // TODO look into this!
                        print("SAMPLE IS BEING PROCESSED TWICE!!! \(sample.value) \(sample.startDate) \(sample.endDate)")
                    }
                    switch kind {
                    case .average:
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
        let retval2 = Array(retval)
//        print("RETVAL:")
//        for sample in retval2 {
//            print("- \(sample.value) \(sample.startDate) \(sample.endDate)")
//        }
        return retval2
    }
    
    
    func aggregated(
        using input: HealthDashboardLayout.SingleValueConfig._Variant,
        overallTimeRange: Range<Date>
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
            let cal = Calendar.current
            var samples = Array(self)
            for step in steps {
                samples = samples.aggregated(
                    using: step.kind,
                    over: step.interval,
                    anchor: cal.startOfDay(for: overallTimeRange.lowerBound),
                    overallTimeRange: overallTimeRange,
                    calendar: cal
                )
            }
            assert(!samples.isEmpty)
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
                            return samples.reduce(0) { $0 + $1.value }
                        case .average:
                            print("calc.avg #samples: \(samples.count)\n\(samples.map { "- \($0.value) \($0.startDate..<$0.endDate)" }.joined(separator: "\n"))")
                            return samples.reduce(0) { $0 + $1.value } / Double(samples.count)
                        }
                    }(),
                    startDate: samples.min(of: \.startDate)!, // swiftlint:disable:this force_unwrapping
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
