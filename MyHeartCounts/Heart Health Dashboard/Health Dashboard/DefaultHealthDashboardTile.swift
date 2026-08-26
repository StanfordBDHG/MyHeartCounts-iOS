//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order file_length

import Charts
import Foundation
import HealthKit
import MyHeartCountsShared
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziViews
import SwiftUI


/// Grid Cell intended for usage in the ``HealthDashboard``, with support for most (quantity-based) sample types.
struct DefaultHealthDashboardTile: View {
    enum QueryInput {
        @available(*, deprecated)
        case firestore(CustomQuantitySampleType)
        /// fetch the data from the server-side stats documents (see ``StatsDocumentsQuery``)
        case statsDocuments(HealthStatsMetric)
    }
    
    enum Accessory {
        case none
        case progress
        case timeRangeSelector(Binding<DetailedHealthStatsView.ChartTimeRange>)
    }
    
    @Environment(\.calendar)
    private var calendar
    
    @Environment(\.healthDashboardGoalProvider)
    private var goalProvider
    
    let queryInput: QueryInput
    let config: HealthDashboardLayout.GridComponent.ComponentDisplayConfig
    let accessory: Accessory
    
    var body: some View {
        switch queryInput {
        case .firestore(let sampleType):
            view(for: sampleType)
        case .statsDocuments(let metric):
            view(for: metric)
        }
    }
    
    private var aggregationMode: QuantitySamplesQueryingViewAggregationMode {
        switch config.style {
        case .singleValue(let config), .gauge(let config, score: _):
            switch config._variant {
            case .mostRecentSample:
                return .mostRecentSample
            case let .aggregated(steps, final):
                if let first = steps.first {
                    return .aggregate(first)
                } else {
                    // if steps is empty, there must be a final step
                    guard let final else {
                        preconditionFailure("unreachable") // enforced by ctors
                    }
                    return .aggregate(.init(kind: final, interval: .for(self.config.timeRange, in: calendar)))
                }
            }
        case .chart(let config):
            switch queryInput {
            case .statsDocuments(let metric):
                return .aggregate(.init(kind: .init(metric.sampleType.hkSampleType.aggregationStyle), interval: config.aggregationInterval))
            case .firestore(let sampleType):
                return .aggregate(.init(kind: sampleType.aggregationKind, interval: config.aggregationInterval))
            }
        }
    }
    
    private func view(for metric: HealthStatsMetric) -> some View {
        SamplesProviderView(
            input: .statsDocuments(metric),
            aggregationMode: self.aggregationMode,
            timeRange: config.timeRange
        ) { samples in
            innerView(for: samples, sampleType: .healthKit(metric.sampleType))
        }
    }
    
    private func view(for sampleType: CustomQuantitySampleType) -> some View {
        SamplesProviderView(
            input: .firestore(sampleType),
            aggregationMode: self.aggregationMode,
            timeRange: config.timeRange
        ) { samples in
            innerView(for: samples, sampleType: .custom(sampleType))
        }
    }
    
    @ViewBuilder
    private func innerView(for samples: [QuantitySample], sampleType: QuantitySample.SampleType) -> some View {
        let samples = {
            switch config.style {
            case .chart:
                samples
            case .singleValue(let config), .gauge(let config, score: _):
                samples.aggregated(using: config._variant, overallTimeRange: self.config.timeRange.range, calendar: calendar)
            }
        }()
        TileImpl(
            sampleType: sampleType,
            samples: samples,
            timeRange: self.config.timeRange,
            style: config.style,
            accessory: accessory,
            goal: goalProvider?(sampleType)
        )
    }
}


private struct TileImpl: View {
    @Environment(\.locale)
    private var locale
    
    @Environment(\.calendar)
    private var cal
    
    private let sampleType: QuantitySample.SampleType
    private let samples: [QuantitySample]
    private let timeRange: HealthKitQueryTimeRange
    private let style: HealthDashboardLayout.Style
    private let accessory: DefaultHealthDashboardTile.Accessory
    private let goal: Achievement.ResolvedGoal?
    
    var body: some View {
        HealthDashboardTile(title: sampleType.displayTitle) {
            switch accessory {
            case .none:
                EmptyView()
            case .progress:
                progressDecoration
            case .timeRangeSelector(let binding):
                ChartTimeRangePicker(timeRange: binding)
            }
        } content: {
            switch style {
            case .chart(let chartConfig):
                let drawingConfig = ChartDataSetDrawingConfig(
                    chartType: chartConfig.chartType,
                    color: sampleType.preferredTintColorForDisplay ?? .blue
                )
                let dataSet = HealthStatsChartDataSet(
                    name: sampleType.displayTitle,
                    sampleType: sampleType,
                    drawingConfig: drawingConfig,
                    data: samples,
                    id: \.id
                ) { (sample: QuantitySample) in
                    HealthStatsChartDataPoint(
                        timeRange: sample.startDate..<sample.endDate,
                        value: sample.value(as: sample.sampleType.displayUnit)
                    )
                } makeHighlightConfig: { dataSet, dataPoint in
                    .default(for: dataPoint, in: dataSet)
                }
                HealthStatsChart(dataSet)
                    .chartXScale(domain: [timeRange.range.lowerBound, timeRange.range.upperBound])
                    .configureChartXAxis(for: timeRange.range)
            case .singleValue:
                singleValueContent(for: samples)
            case let .gauge(_, score):
                gaugeContent(for: samples, score: score)
            }
        }
    }
    
    
    @ViewBuilder private var progressDecoration: some View {
        if style.effectiveAggregationKind(for: sampleType) == .sum, let goal {
            let currentTotal = samples.reduce(into: 0) { total, sample in
                total += sample.value(as: sample.sampleType.displayUnit)
            }
            let progress = goal.evaluate(HKQuantity(unit: sampleType.displayUnit, doubleValue: currentTotal), unit: sampleType.displayUnit)
            CircularProgressView(progress, lineWidth: 3) // could also use the gauge here...
                .frame(width: 27, height: 27)
        }
    }
    
    fileprivate init(
        sampleType: QuantitySample.SampleType,
        samples: [QuantitySample],
        timeRange: HealthKitQueryTimeRange,
        style: HealthDashboardLayout.Style,
        accessory: DefaultHealthDashboardTile.Accessory,
        goal: Achievement.ResolvedGoal?
    ) {
        self.sampleType = sampleType
        self.samples = samples
        self.timeRange = timeRange
        self.style = style
        self.accessory = accessory
        self.goal = goal
    }
    
    @ViewBuilder
    private func gaugeContent(for samples: [QuantitySample], score: ScoreDefinition) -> some View {
        VStack {
            let input = singleValueInput(for: samples)
            let progress = input?.value.map { score($0) }
            let currentValueText: Text? = input.map { input in
                Text(input.valueString + (input.unitString.isEmpty ? "" : " \(input.unitString)")) // maybe have the unit someplace else?
                    .font(.caption2)
            }
            let makeGaugeBoundaryText = { (value: Double) -> Text in
                Text(value, format: .number.notation(.compactName))
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Group {
                switch score.variant {
                case .distinctMapping, .custom:
                    Gauge(
                        gradient: .redToGreen,
                        progress: progress
                    ) { currentValueText }
                case .range(let range, _):
                    Gauge(gradient: .redToGreen, progress: progress) {
                        currentValueText
                    } minimumValueText: {
                        makeGaugeBoundaryText(range.lowerBound)
                    } maximumValueText: {
                        // technically we might need to adjust the value here a bit (it's an exclusive range),
                        // but since we use `.number.notation(.compactName)` when formatting, it should be fine.
                        makeGaugeBoundaryText(range.upperBound)
                    }
                }
            }
            .frame(width: 58, height: 58)
            if let input {
                // NOTE: displaying the entire range (or even just the range's upper bound) here technically won't always be correct
                // (it's not incorrect either, just not perfect):
                // if we have a single-value grid cell that displays the max heart rate measured today, we'd have the label at the bottom say
                // "Today", even though displaying the precise time of this max heart rate measurement would be more correct.
                Text(input.timeRange.upperBound.shortDescription())
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }
    
    
    private func singleValueInput(for samples: [QuantitySample]) -> HealthDashboardQuantityLabel.Input? {
        assert(samples.allSatisfy { $0.sampleType == sampleType })
        let unit = sampleType.displayUnit
        switch style.effectiveAggregationKind(for: sampleType) {
        case .sum:
            if let lastSample = samples.last {
                let total = samples.reduce(0) { $0 + $1.value(as: unit) }
                switch sampleType {
                case .healthKit(let sampleType):
                    return .init(
                        value: total,
                        unit: unit,
                        sampleType: .healthKit(sampleType),
                        timeRange: lastSample.timeRange
                    )
                case .custom:
                    return .init(
                        value: total,
                        valueString: "\(total)", // ideally we'd make this look nice; depending on the SampleType
                        unit: unit,
                        timeRange: lastSample.timeRange
                    )
                }
            } else {
                return nil
            }
        case .avg, .min, .max:
            // in the case of an average-based aggregation, i.e. in the case of all non-cumulative sample types,
            // we instead display the last. this works since samples will already be properly pre-processed in this case.
            if let lastSample = samples.last {
                switch sampleType {
                case .healthKit(let sampleType):
                    return .init(
                        value: lastSample.value(as: unit),
                        unit: unit,
                        sampleType: .healthKit(sampleType),
                        timeRange: lastSample.timeRange
                    )
                case .custom:
                    return .init(
                        value: lastSample.value(as: unit),
                        valueString: "\(lastSample.value(as: unit))",
                        unit: unit,
                        timeRange: lastSample.timeRange
                    )
                }
            } else {
                return nil
            }
        }
    }
    
    @ViewBuilder
    private func singleValueContent(for samples: [QuantitySample]) -> some View {
        if let input = singleValueInput(for: samples) {
            HealthDashboardQuantityLabel(input: input)
        } else {
            Text("n/a")
        }
    }
}


// MARK: SamplesProviderView

private struct SamplesProviderView<Content: View>: View {
    @Environment(\.calendar)
    private var calendar
    private let input: DefaultHealthDashboardTile.QueryInput
    private let aggregationMode: QuantitySamplesQueryingViewAggregationMode
    private let timeRange: HealthKitQueryTimeRange
    private let content: @MainActor ([QuantitySample]) -> Content
    
    var body: some View {
        switch input {
        case .firestore(let sampleType):
            FirestoreImpl(
                samples: .init(sampleType: sampleType, timeRange: timeRange),
                content: content
            )
        case .statsDocuments(let metric):
            StatsDocumentsImpl(
                samples: .init(metric: metric, timeRange: timeRange, aggregationKind: aggregationKindForStatsDocuments(metric: metric)),
                aggregationMode: aggregationMode,
                timeRange: timeRange,
                content: content
            )
        }
    }
    
    init(
        input: DefaultHealthDashboardTile.QueryInput,
        aggregationMode: QuantitySamplesQueryingViewAggregationMode,
        timeRange: HealthKitQueryTimeRange,
        @ViewBuilder content: @escaping @MainActor ([QuantitySample]) -> Content
    ) {
        self.input = input
        self.aggregationMode = aggregationMode
        self.timeRange = timeRange
        self.content = content
    }
    
    /// which of a bucketed stats-document entry's values should become the resulting sample's value
    private func aggregationKindForStatsDocuments(metric: HealthStatsMetric) -> StatisticsAggregationOption {
        switch aggregationMode {
        case .aggregate(let strategy):
            strategy.kind
        case .none, .mostRecentSample:
            .init(metric.sampleType.hkSampleType.aggregationStyle)
        }
    }
}


extension SamplesProviderView {
    private struct StatsDocumentsImpl: View {
        @Environment(\.calendar)
        private var calendar
        @StatsDocumentsQuery<QuantitySample> var samples: [QuantitySample]
        let aggregationMode: QuantitySamplesQueryingViewAggregationMode
        let timeRange: HealthKitQueryTimeRange
        let content: @MainActor ([QuantitySample]) -> Content
        
        var body: some View {
            switch aggregationMode {
            case .none:
                content(samples)
            case .mostRecentSample:
                // NOTE: for metrics whose stats documents store aggregated buckets (e.g. hourly), the "most recent sample"
                // is the most recent *bucket* (with the bucket's time range), not the most recent raw reading.
                if let sample = samples.max(by: \.endDate) {
                    content([sample])
                } else {
                    content([])
                }
            case .aggregate(let strategy):
                // reduce the stats documents' entries into one sample per aggregation interval,
                // mirroring what the HKStatisticsQuery-based provider produces for the HealthKit path.
                // note that the achievable resolution is limited by what the stats documents store (e.g., hourly buckets).
                content(samples.reducedIntoIntervals(
                    using: strategy.kind,
                    over: strategy.interval,
                    anchor: calendar.startOfDay(for: timeRange.range.lowerBound),
                    overallTimeRange: timeRange.range,
                    calendar: calendar
                ))
            }
        }
    }
    
    private struct FirestoreImpl: View {
        @MHCFirestoreQuery<QuantitySample> var samples: [QuantitySample]
        let content: @MainActor ([QuantitySample]) -> Content
        
        var body: some View {
            content(samples)
        }
    }
}
