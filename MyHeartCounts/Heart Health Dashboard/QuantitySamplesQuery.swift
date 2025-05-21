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
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftData
import SwiftUI


/// How a collection of quantity samples should be aggregated into a collection of aggregated quantity samples
struct QuantitySamplesAggregationStrategy {
    /// The operation that should be used to aggregate a subset of the samples
    let kind: StatisticsQueryAggregationKind
    /// The time interval, for which a subset of the input samples should be turned into an aggregated sample
    let interval: HealthKitStatisticsQuery.AggregationInterval
}


enum QuantitySamplesQueryingViewAggregationMode {
    /// the individual samples should be fetched and returned as-is
    case none
    /// we're only interested in the most recent sample. no additional processing should happen
    case mostRecentSample
    /// the individual samples should be processed into aggregated samples, using a specific kind and over the specified interval
    case aggregate(QuantitySamplesAggregationStrategy)
}



extension HealthKitStatisticsQuery {
    init(
        _ sampleType: SampleType<HKQuantitySample>,
        aggregatedBy: StatisticsQueryAggregationKind,
        over aggregationInterval: AggregationInterval,
        timeRange: HealthKitQueryTimeRange,
        filter: NSPredicate? = nil
    ) {
        switch aggregatedBy {
        case .sum:
            self.init(sampleType, aggregatedBy: [.sum], over: aggregationInterval, timeRange: timeRange, filter: filter)
        case .average:
            self.init(sampleType, aggregatedBy: [.average], over: aggregationInterval, timeRange: timeRange, filter: filter)
        }
    }
}
