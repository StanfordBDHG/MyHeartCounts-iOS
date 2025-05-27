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


struct HealthDashboardQuantityComponentGridCell: View {
    enum InputSampleType { // TODO rename! QueryInput? Input? DataSource?
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
    
    let inputSampleType: InputSampleType
    let config: HealthDashboardLayout.GridComponent.QuantityDisplayComponentConfig
    
    var body: some View {
        switch inputSampleType {
        case .healthKit(let sampleType):
            view(for: sampleType)
        case .custom(let dataSource):
            view(for: dataSource)
        }
    }
    
    private var timeRange: HealthKitQueryTimeRange {
        switch inputSampleType {
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
                        preconditionFailure() // TODO error message!
                    }
                    return .aggregate(.init(kind: final, interval: .for(timeRange)))
                }
            }
        case .chart(let config):
            switch inputSampleType {
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
                samples.aggregated(using: config._variant, overallTimeRange: timeRange.range)
            }
        }()
        QuantityHealthStatGridCell2(
            sampleType: sampleType,
            samples: samples,
            timeRange: timeRange,
            style: config.style,
            goal: Achievement.ResolvedGoal?.none// goalProvider?(sampleType)
        )
    }
}


extension EnvironmentValues {
    @Entry var tmp_showTimeRangeAsGridCellSubtitle: Bool = false
}


// TODO rename and ideally merge into the view above?!
private struct QuantityHealthStatGridCell2: View {
    @Environment(\.calendar) private var cal
    @Environment(\.tmp_showTimeRangeAsGridCellSubtitle)
    private var showTimeRangeAsSubtitle
    
    private let sampleType: QuantitySample.SampleType
    private let samples: [QuantitySample]
    private let timeRange: HealthKitQueryTimeRange
    private let style: HealthDashboardLayout.Style
    private let goal: Achievement.ResolvedGoal?
    
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
                let trendlineDataSet = HealthStatsChartDataSet(
                    name: "Trendline",
                    drawingConfig: .init(chartType: .line(), color: .red),
                    dataPoints: [
                        .init(date: .today, value: 50),
                        .init(date: .tomorrow, value: 150)
                    ]
                )
                HealthStatsChart(
//                    trendlineDataSet,
                    dataSet
                )
                .chartXScale(domain: [timeRange.range.lowerBound, timeRange.range.upperBound])
                .configureChartXAxisWithDailyMarks(forTimeRange: timeRange.range)
//                Text("\(timeRange.range)")
            case .singleValue:
                singleValueContent(for: samples)
            case .gauge:
                gaugeContent(for: samples)
            }
        }
    }
    
    
    @ViewBuilder private var progressDecoration: some View {
        if style.effectiveAggregationKind(for: sampleType) == .sum, let goal {
            let dailyTotalGoal = goal.quantity.doubleValue(for: sampleType.displayUnit)
            let currentTotal = samples.reduce(into: 0) { total, sample in
                total += sample.value
            }
            if false {
                //                CircularProgressView(currentTotal / dailyTotalGoal, lineWidth: 2.5, showProgressAsLabel: true)
                //                //                        .tint(sampleType.preferredTintColorForDisplay) // TODO!!!
                //                    .frame(height: 27)
                //                    .font(.system(size: 7))
            } else {
                HStack {
                    Gauge2(lineWidth: .relative(0.5), gradient: .greenToRed, progress: currentTotal / dailyTotalGoal)
                        .frame(width: 27, height: 27)
                    CircularProgressView(currentTotal / dailyTotalGoal, lineWidth: 3)
                        .frame(width: 27, height: 27)
                }
            }
        }
    }
    
    @ViewBuilder
    private func gaugeContent(for samples: [QuantitySample]) -> some View {
        if let goal = goal {
            let target = goal.quantity.doubleValue(for: sampleType.displayUnit)
//            let value: Double = { () -> Double? in
//                switch config {
//                case .mostRecentSample:
//                    return samples.last?.value
//                case .aggregated(let kind):
//                    print("SAMPLES: \(samples)")
//                    let aggd = samples.aggregated(using: kind, over: .day, anchor: cal.startOfDay(for: .now), overallTimeRange: .today...Date.tomorrow)
//                    print("AGG'D: \(aggd)")
//                    return samples.last?.value
////                            // TODO why doesn't this work? (should just return the input again!
////                            return samples.aggregated(using: kind, over: .day, anchor: cal.startOfDay(for: .now), overallTimeRange: .today...Date.tomorrow)
//                }
//            }() ?? 0
            let value = samples.last?.value ?? 0
            let scaledValue = value / target
            Gauge2(gradient: .redToGreen, progress: scaledValue)
//                .gauge2Style(Gauge2StyleGauge(gradient: .greenToRed.reversed()))
                .frame(width: 58, height: 58)
            // TODO we somehow need to get a **single** value, and then scale it into a 0...1 range, which indicates bad...good!
        } else {
            Text("TODO: MISSING GOAL!!!")
        }
    }
    
    private func singleValueContent(for samples: [QuantitySample]) -> some View {
        let _ = print("\(#function) #samples: \(samples.count)")
        @ViewBuilder
        func makeView(for input: HealthDashboardQuantityLabel.Input?) -> some View {
            if let input {
                HealthDashboardQuantityLabel(input: input)
            } else {
                Text("n/a") // TODO!!!
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
                        valueString: "\(total)", // TODO make this look nice; depending on the SampleType!!!
                        unitString: sampleType.displayUnit.unitString,
                        timeRange: lastSample.timeRange
                    )
                }
            } else {
                input = nil
            }
        case .average:
            // in the case of an average-based aggregation, i.e. in the case of all non-cumulative sample types,
            // we instead display the most recent sample
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
    private let input: HealthDashboardQuantityComponentGridCell.InputSampleType
    private let aggregationMode: QuantitySamplesQueryingViewAggregationMode
    private let timeRange: HealthKitQueryTimeRange
    private let content: @MainActor ([QuantitySample]) -> Content
    
    init(
        input: HealthDashboardQuantityComponentGridCell.InputSampleType,
        aggregationMode: QuantitySamplesQueryingViewAggregationMode,
        timeRange: HealthKitQueryTimeRange,
        @ViewBuilder content: @escaping @MainActor ([QuantitySample]) -> Content
    ) {
        self.input = input
        self.aggregationMode = aggregationMode
        self.timeRange = timeRange
        self.content = content
    }
    
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
                    statistics: .init(sampleType, aggregatedBy: .init(sampleType.hkSampleType.aggregationStyle), over: .for(timeRange), timeRange: timeRange),
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
            CustomDataSourceImpl(samples: dataSource, content: content)
//        case .custom(let sampleType): // TODO remove this eventually? (it's not necessarily a quantity type!!!)
//            let timeRange = timeRange.range
//            let sampleTimeFilter = { () -> Predicate<CustomHealthSample> in
//                switch aggregationMode {
//                case .none:
//                    // we want to match all samples that are fully contained within the time range
//                    return #Predicate { sample in
//                        sample.startDate >= timeRange.lowerBound && sample.endDate < timeRange.upperBound
//                    }
//                case .mostRecentSample:
//                    // we want to match all samples that end within the time range
//                    return #Predicate { sample in
//                        // we can't simply write `timeRange.contains(sample.endDate)` in the predicate...
//                        sample.endDate >= timeRange.lowerBound && sample.endDate < timeRange.upperBound
//                    }
//                case .aggregate:
//                    // we want to match any sample that overlaps with the time range
//                    return #Predicate { sample in
//                        timeRange.lowerBound < sample.endDate && timeRange.upperBound > sample.startDate // TODO is this correct?
//                    }
//                }
//            }()
//            let sampleTypeRawValue = sampleType.rawValue
//            let fetchDescriptor = FetchDescriptor<CustomHealthSample>(
//                predicate: #Predicate { sample in
//                    sample.sampleTypeRawValue == sampleTypeRawValue && sampleTimeFilter.evaluate(sample)
//                },
//                sortBy: [SortDescriptor<CustomHealthSample>(\.startDate)]
//            )
//            SwiftDataImpl(
//                _samples: .init(fetchDescriptor),
//                timeRange: timeRange,
//                aggregationMode: aggregationMode,
//                content: content
//            )
        }
    }
}

extension SamplesProviderView {
    private struct HealthKitImpl_SamplesQuery: View {
        @HealthKitQuery<HKQuantitySample> var samples: Slice<OrderedArray<HKQuantitySample>>
        let aggregationMode: QuantitySamplesQueryingViewAggregationMode // TODO unify name!
        let content: @MainActor ([QuantitySample]) -> Content
        
        private var sampleType: SampleType<HKQuantitySample> {
            $samples.sampleType
        }
        
        var body: some View {
            switch aggregationMode {
            case .none:
                content(samples.map { QuantitySample($0) })
            case .mostRecentSample:
                let _ = print("#samples: \(samples.count)")
                if let sample = samples.last {
                    content([QuantitySample(sample)])
                } else {
                    content([])
                }
            case .aggregate(let strategy):
                let _ = fatalError("Unreachable. Should be using the '\(HealthKitImpl_StatisticsQuery.self)' in this case")
                EmptyView()
            }
        }
    }
    
    private struct HealthKitImpl_StatisticsQuery: View {
        @HealthKitStatisticsQuery var statistics: [HKStatistics]
        let aggregationKind: StatisticsQueryAggregationKind // TODO unify name!
        let limitToMostRecentSample: Bool
        let content: @MainActor ([QuantitySample]) -> Content
        
        private var sampleType: SampleType<HKQuantitySample> {
            $statistics.sampleType
        }
        
        var body: some View {
            let samples = { () -> [QuantitySample] in
                if limitToMostRecentSample {
                    guard let statistics = statistics.last,
                          let quantity = statistics.mostRecentQuantity(),
                          let timeInterval = statistics.mostRecentQuantityDateInterval() else {
                        return []
                    }
                    return [QuantitySample(
                        id: UUID(), // aaaaarugh
                        sampleType: .healthKit(sampleType),
                        unit: sampleType.displayUnit,
                        value: quantity.doubleValue(for: sampleType.displayUnit),
                        startDate: timeInterval.start,
                        endDate: timeInterval.end
                    )]
                } else {
                    return statistics.compactMap { statistics -> QuantitySample? in
                        let quantity: HKQuantity?
                        switch aggregationKind {
                        case .sum:
                            quantity = statistics.sumQuantity()
                        case .average:
                            quantity = statistics.averageQuantity()
                        }
                        guard let quantity else {
                            return nil
                        }
                        return QuantitySample(
                            id: UUID(), // TODO is this a good idea?
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
    
    
//    // TODO remove?
//    private struct SwiftDataImpl: View {
//        @Environment(\.calendar) private var cal
//        @Query var samples: [CustomHealthSample]
//        let timeRange: Range<Date>
//        let aggregationMode: QuantitySamplesQueryingViewAggregationMode
//        let content: @MainActor ([QuantitySample]) -> Content
//        
//        var body: some View {
//            content(processedSamples())
//        }
//        
//        private func processedSamples() -> [QuantitySample] {
//            switch aggregationMode {
//            case .none:
//                samples.map { QuantitySample($0) }
//            case .mostRecentSample:
//                samples.suffix(1).map { QuantitySample($0) }
//            case .aggregate(let strategy):
//                if let sample = samples.first {
//                    samples.lazy
//                        .map { QuantitySample($0) }
//                        .aggregated(using: strategy.kind, over: strategy.interval, anchor: cal.startOfDay(for: sample.startDate), overallTimeRange: timeRange)
//                } else {
//                    []
//                }
//            }
//        }
//    }
    
    
    private struct CustomDataSourceImpl: View {
        var samples: any HealthDashboardLayout.CustomDataSourceProtocol // TOOD is this enough to get @Observable behaviour?
        let content: @MainActor ([QuantitySample]) -> Content
        
        var body: some View {
            content(Array(samples))
        }
    }
}
