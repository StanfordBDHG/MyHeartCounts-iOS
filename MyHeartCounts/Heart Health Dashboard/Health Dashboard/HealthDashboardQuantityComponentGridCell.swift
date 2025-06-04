//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import HealthKit
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftData
import SwiftUI


struct HealthDashboardQuantityComponentGridCell: View {
    enum QueryInput {
        case healthKit(SampleType<HKQuantitySample>)
        case custom(any HealthDashboardLayout.CustomDataSourceProtocol)
        
        init?(_ dataSource: HealthDashboardLayout.DataSource) {
            switch dataSource {
            case .healthKit(.quantity(let sampleType)):
                self = .healthKit(sampleType)
            case .healthKit:
                return nil
            case .custom(let dataSource):
                self = .custom(dataSource)
            }
        }
    }
    
    @Environment(\.calendar)
    private var calendar
    let queryInput: QueryInput
    let config: HealthDashboardLayout.GridComponent.ComponentDisplayConfig
    
    var body: some View {
        switch queryInput {
        case .healthKit(let sampleType):
            view(for: sampleType)
        case .custom(let dataSource):
            view(for: dataSource)
        }
    }
    
    private var timeRange: HealthKitQueryTimeRange {
        switch queryInput {
        case .custom(let dataSource):
            dataSource.timeRange
        case .healthKit:
            config.timeRange
        }
    }
    
    private var aggregationMode: QuantitySamplesQueryingViewAggregationMode {
        switch config.style {
        case .singleValue(let config), .gauge(let config):
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
                    return .aggregate(.init(kind: final, interval: .for(timeRange, in: calendar)))
                }
            }
        case .chart(let config):
            switch queryInput {
            case .healthKit(let sampleType):
                return .aggregate(.init(kind: .init(sampleType.hkSampleType.aggregationStyle), interval: config.aggregationInterval))
            case .custom(let dataSource):
                return .aggregate(.init(kind: dataSource.sampleType.aggregationKind, interval: config.aggregationInterval))
            }
        }
    }
    
    private func view(for sampleType: SampleType<HKQuantitySample>) -> some View {
        SamplesProviderView(
            input: .healthKit(sampleType),
            aggregationMode: self.aggregationMode,
            timeRange: config.timeRange
        ) { samples in
            innerView(for: samples, sampleType: .healthKit(sampleType))
        }
    }
    
    private func view(for dataSource: any HealthDashboardLayout.CustomDataSourceProtocol) -> some View {
        SamplesProviderView(
            input: .custom(dataSource),
            aggregationMode: self.aggregationMode,
            timeRange: self.config.timeRange
        ) { samples in
            innerView(for: samples, sampleType: .custom(dataSource.sampleType))
        }
    }
    
    @ViewBuilder
    private func innerView(for samples: [QuantitySample], sampleType: QuantitySample.SampleType) -> some View {
        let samples = {
            switch config.style {
            case .chart:
                samples
            case .singleValue(let config), .gauge(let config):
                samples.aggregated(using: config._variant, overallTimeRange: timeRange.range, calendar: calendar)
            }
        }()
        GridCellImpl(
            sampleType: sampleType,
            samples: samples,
            timeRange: timeRange,
            style: config.style,
            goal: Achievement.ResolvedGoal?.none// goalProvider?(sampleType)
        )
    }
}


extension EnvironmentValues {
    @Entry var showTimeRangeAsGridCellSubtitle: Bool = false // not ideal but it works
}


private struct GridCellImpl: View {
    @Environment(\.calendar)
    private var cal
    @Environment(\.showTimeRangeAsGridCellSubtitle)
    private var showTimeRangeAsSubtitle
    
    private let sampleType: QuantitySample.SampleType
    private let samples: [QuantitySample]
    private let timeRange: HealthKitQueryTimeRange
    private let style: HealthDashboardLayout.Style
    private let goal: Achievement.ResolvedGoal?
    
    var body: some View {
        HealthDashboardSmallGridCell(
            title: sampleType.displayTitle,
            subtitle: showTimeRangeAsSubtitle ? timeRange.range.displayText(using: cal) : nil
        ) {
            progressDecoration
        } content: {
            switch style {
            case .chart(let chartConfig):
                let drawingConfig = ChartDataSetDrawingConfig(
                    chartType: chartConfig.chartType,
                    color: sampleType.preferredTintColorForDisplay ?? .blue
                )
                let dataSet = HealthStatsChartDataSet(
                    name: sampleType.displayTitle,
                    drawingConfig: drawingConfig,
                    data: samples,
                    id: \.id
                ) { (sample: QuantitySample) in
                    HealthStatsChartDataPoint(timeRange: sample.startDate..<sample.endDate, value: sample.value)
                }
                HealthStatsChart(dataSet)
                    .chartXScale(domain: [timeRange.range.lowerBound, timeRange.range.upperBound])
                    .configureChartXAxisWithDailyMarks(forTimeRange: timeRange.range)
            case .singleValue:
                singleValueContent(for: samples)
            case .gauge:
                gaugeContent(for: samples)
            }
        }
    }
    
    
    @ViewBuilder private var progressDecoration: some View {
        if style.effectiveAggregationKind(for: sampleType) == .sum, let goal {
            let currentTotal = samples.reduce(into: 0) { total, sample in
                total += sample.value
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
        goal: Achievement.ResolvedGoal?
    ) {
        self.sampleType = sampleType
        self.samples = samples
        self.timeRange = timeRange
        self.style = style
        self.goal = goal
    }
    
    @ViewBuilder
    private func gaugeContent(for samples: [QuantitySample]) -> some View {
        if let goal {
            let progress = goal.evaluate(
                HKQuantity(unit: sampleType.displayUnit, doubleValue: samples.last?.value ?? 0),
                unit: sampleType.displayUnit
            )
            Gauge2(gradient: .redToGreen, progress: progress)
                .frame(width: 58, height: 58)
        } else {
            Text("TODO: MISSING GOAL!!!")
        }
    }
    
    private func singleValueContent(for samples: [QuantitySample]) -> some View { // swiftlint:disable:this function_body_length
        @ViewBuilder
        func makeView(for input: HealthDashboardQuantityLabel.Input?) -> some View {
            if let input {
                HealthDashboardQuantityLabel(input: input)
            } else {
                Text("n/a")
            }
        }
        
        let input: HealthDashboardQuantityLabel.Input?
        switch style.effectiveAggregationKind(for: sampleType) {
        case .sum:
            if let lastSample = samples.last {
                let total = samples.reduce(0) { $0 + $1.value }
                switch sampleType {
                case .healthKit(let sampleType):
                    input = .init(
                        value: total,
                        sampleType: .healthKit(sampleType),
                        timeRange: lastSample.timeRange
                    )
                case .custom(let sampleType):
                    input = .init(
                        valueString: "\(total)", // ideally we'd make this look nice; depending on the SampleType
                        unitString: sampleType.displayUnit.unitString,
                        timeRange: lastSample.timeRange
                    )
                }
            } else {
                input = nil
            }
        case .avg, .min, .max:
            // in the case of an average-based aggregation, i.e. in the case of all non-cumulative sample types,
            // we instead display the last. this works since samples will already be properly pre-processed in this case.
            if let lastSample = samples.last {
                switch sampleType {
                case .healthKit(let sampleType):
                    input = .init(
                        value: lastSample.value,
                        sampleType: .healthKit(sampleType),
                        timeRange: lastSample.timeRange
                    )
                case .custom:
                    input = .init(
                        valueString: "\(lastSample.value)",
                        unitString: lastSample.unit.unitString,
                        timeRange: lastSample.timeRange
                    )
                }
            } else {
                input = nil
            }
        }
        return makeView(for: input)
    }
}


// MARK: SamplesProviderView

private struct SamplesProviderView<Content: View>: View {
    @Environment(\.calendar)
    private var calendar
    private let input: HealthDashboardQuantityComponentGridCell.QueryInput
    private let aggregationMode: QuantitySamplesQueryingViewAggregationMode
    private let timeRange: HealthKitQueryTimeRange
    private let content: @MainActor ([QuantitySample]) -> Content
    
    var body: some View {
        switch input {
        case .healthKit(let sampleType):
            switch aggregationMode {
            case .none:
                // if we're not supposed to aggregate anything, we simply perform a "normal" query that fetches all samples
                HealthKitImpl_SamplesQuery(
                    samples: HealthKitQuery(sampleType, timeRange: timeRange),
                    aggregationMode: aggregationMode,
                    content: content
                )
            case .mostRecentSample:
                // if we're supposed to fetch only the most recent sample, we, for performance reasons, handle this as a statistics query and instruct the
                // view to only return the most recent sample.
                // this is significantly faster than using a HealthKitQuery over the same time range and looking at only the most recent result in there.
                HealthKitImpl_StatisticsQuery(
                    statistics: .init(
                        sampleType,
                        aggregatedBy: .init(sampleType.hkSampleType.aggregationStyle),
                        over: .for(timeRange, in: calendar),
                        timeRange: timeRange
                    ),
                    aggregationKind: .init(sampleType.hkSampleType.aggregationStyle),
                    limitToMostRecentSample: true,
                    content: content
                )
            case .aggregate(let strategy):
                HealthKitImpl_StatisticsQuery(
                    statistics: .init(sampleType, aggregatedBy: strategy.kind, over: strategy.interval, timeRange: timeRange),
                    aggregationKind: strategy.kind,
                    limitToMostRecentSample: false,
                    content: content
                )
            }
        case .custom(let dataSource):
            CustomDataSourceImpl(dataSource: dataSource, content: content)
        }
    }
    
    init(
        input: HealthDashboardQuantityComponentGridCell.QueryInput,
        aggregationMode: QuantitySamplesQueryingViewAggregationMode,
        timeRange: HealthKitQueryTimeRange,
        @ViewBuilder content: @escaping @MainActor ([QuantitySample]) -> Content
    ) {
        self.input = input
        self.aggregationMode = aggregationMode
        self.timeRange = timeRange
        self.content = content
    }
}


extension SamplesProviderView {
    private struct HealthKitImpl_SamplesQuery: View { // swiftlint:disable:this type_name
        @HealthKitQuery<HKQuantitySample> var samples: Slice<OrderedArray<HKQuantitySample>>
        let aggregationMode: QuantitySamplesQueryingViewAggregationMode
        let content: @MainActor ([QuantitySample]) -> Content
        
        private var sampleType: SampleType<HKQuantitySample> {
            $samples.sampleType
        }
        
        var body: some View {
            switch aggregationMode {
            case .none:
                content(samples.map { QuantitySample($0) })
            case .mostRecentSample:
                if let sample = samples.last {
                    content([QuantitySample(sample)])
                } else {
                    content([])
                }
            case .aggregate:
                // swiftlint:disable:next redundant_discardable_let
                let _ = fatalError("Unreachable. Should be using the '\(HealthKitImpl_StatisticsQuery.self)' in this case")
            }
        }
    }
}


extension SamplesProviderView {
    private struct HealthKitImpl_StatisticsQuery: View { // swiftlint:disable:this type_name
        @HealthKitStatisticsQuery var statistics: [HKStatistics]
        let aggregationKind: StatisticsAggregationOption
        let limitToMostRecentSample: Bool
        let content: @MainActor ([QuantitySample]) -> Content
        
        private var sampleType: SampleType<HKQuantitySample> {
            $statistics.sampleType
        }
        
        var body: some View {
            let samples = { () -> [QuantitySample] in // swiftlint:disable:this closure_body_length
                if limitToMostRecentSample {
                    guard let statistics = statistics.last,
                          let quantity = statistics.mostRecentQuantity(),
                          let timeInterval = statistics.mostRecentQuantityDateInterval() else {
                        return []
                    }
                    return [
                        QuantitySample(
                            id: UUID(), // aaaaarugh
                            sampleType: .healthKit(sampleType),
                            unit: sampleType.displayUnit,
                            value: quantity.doubleValue(for: sampleType.displayUnit),
                            startDate: timeInterval.start,
                            endDate: timeInterval.end
                        )
                    ]
                } else {
                    return statistics.compactMap { statistics -> QuantitySample? in
                        let quantity: HKQuantity?
                        switch aggregationKind {
                        case .sum:
                            quantity = statistics.sumQuantity()
                        case .avg:
                            quantity = statistics.averageQuantity()
                        case .min:
                            quantity = statistics.minimumQuantity()
                        case .max:
                            quantity = statistics.maximumQuantity()
                        }
                        guard let quantity else {
                            return nil
                        }
                        return QuantitySample(
                            id: UUID(),
                            sampleType: .healthKit(sampleType),
                            unit: sampleType.displayUnit,
                            value: quantity.doubleValue(for: sampleType.displayUnit),
                            startDate: statistics.startDate,
                            endDate: statistics.endDate
                        )
                    }
                }
            }()
            content(samples)
        }
    }
}


extension SamplesProviderView {
    private struct CustomDataSourceImpl: View {
        var dataSource: any HealthDashboardLayout.CustomDataSourceProtocol // TOOD is this enough to get @Observable behaviour?
        let content: @MainActor ([QuantitySample]) -> Content
        
        var body: some View {
            content(Array(dataSource.samples))
        }
    }
}
