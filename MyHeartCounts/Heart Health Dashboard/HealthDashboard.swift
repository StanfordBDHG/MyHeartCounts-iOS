//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Charts
import Foundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


struct HealthDashboard: View {
    @Environment(HeartHealthManager.self)
    private var manager
    
    var body: some View {
        ScrollView {
            ForEach(manager.layout.blocks, id: \.self) { block in
                let content = Group {
                    switch block.content {
                    case let .large(sampleType, chartConfig):
                        makeChart(for: sampleType, withConfig: chartConfig ?? .default(for: sampleType))
                    case .grid(let components):
                        makeGrid(with: components)
                    }
                }
                if let title = block.title {
                    Section(title) {
                        content
                    }
                } else {
                    Section {
                        content
                    }
                }
            }
            .padding(.horizontal)
            Section {
                SleepPhasesCharts()
                    .frame(height: 400)
            }
            .padding(.horizontal)
        }
        .makeBackgroundMatchFormBackground()
    }
    
    @ViewBuilder
    private func makeGrid(with components: [HealthDashboardLayout.GridComponent]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12, alignment: .top),
            GridItem(.flexible(), alignment: .top)
        ]
        LazyVGrid(columns: columns, alignment: .center, spacing: 12, pinnedViews: .sectionHeaders) {
            ForEach(Array(components.indices), id: \.self) { idx in
                makeView(for: components[idx])
            }
        }
    }
    
    
    @ViewBuilder
    private func makeView(for component: HealthDashboardLayout.GridComponent) -> some View {
        switch component.sampleType {
        case .quantity(let sampleType):
//            QuantityHealthStatGridCell(sampleType, dailyTotalGoal: manager.goals[sampleType], chartConfig: nil)
            QuantityHealthStatGridCell(
                sampleType,
                dailyTotalGoal: manager.goals[sampleType],
                chartConfig: component.chartConfig ?? .default(for: sampleType)
            )
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func makeChart(for sampleType: SampleType<HKQuantitySample>, withConfig config: QuantityHealthStatGridCell.ChartConfig) -> some View {
        // TODO!
        EmptyView()
    }
}



private struct SmallGridCell<Detail: View, Content: View>: View {
    private static var insets: EdgeInsets { EdgeInsets(horizontal: 9, vertical: 5) }
    
    private let title: String
    private let detail: @MainActor () -> Detail
    private let content: @MainActor () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    detail()
                }
                .padding(EdgeInsets(top: Self.insets.top, leading: 0, bottom: Self.insets.top, trailing: 0))
                .frame(height: 57)
                Divider()
            }
            Spacer()
            content()
            Spacer()
        }
        .padding(EdgeInsets(top: 0, leading: Self.insets.leading, bottom: Self.insets.bottom, trailing: Self.insets.trailing))
        .frame(minHeight: 129)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    
    init(
        title: String,
        @ViewBuilder detail: @MainActor @escaping () -> Detail = { EmptyView() },
        @ViewBuilder content: @MainActor @escaping () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content
    }
}


struct QuantityHealthStatGridCell: View {
    static let numberFormatter: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal // TODO change it to cache & offer multiple formatters (eg also a percent one)
        fmt.minimumFractionDigits = 0
        fmt.maximumFractionDigits = 2
        return fmt
    }()
    
    enum AggregationKind {
        case sum, average
        
        init(_ other: HKQuantityAggregationStyle) {
            switch other {
            case .cumulative:
                self = .sum
            case .discreteArithmetic:
                self = .average
            case .discreteTemporallyWeighted:
                self = .average
            case .discreteEquivalentContinuousLevel:
                fatalError("Currently not supported")
            @unknown default:
                fatalError("Currently not supported")
            }
        }
    }
    
    private let sampleType: SampleType<HKQuantitySample>
    private let chartConfig: ChartConfig?
    private let aggregationKind: AggregationKind
    private let dailyTotalGoal: Double? // TODO also support a weekly total? would we have a use case for that?
    @HealthKitStatisticsQuery private var stats: [HKStatistics] // TODO the type shouldn't be necessary here!
    
    init(_ sampleType: SampleType<HKQuantitySample>, dailyTotalGoal: HKQuantity?, chartConfig: ChartConfig?) {
        self.init(sampleType, dailyTotalGoal: dailyTotalGoal?.doubleValue(for: sampleType.displayUnit), chartConfig: chartConfig)
    }
    
    init(_ sampleType: SampleType<HKQuantitySample>, dailyTotalGoal: Double? = nil, chartConfig: ChartConfig?) {
        self.sampleType = sampleType
        self.chartConfig = chartConfig
        self.dailyTotalGoal = dailyTotalGoal
        self.aggregationKind = .init(sampleType.hkSampleType.aggregationStyle)
        if let chartConfig {
            switch aggregationKind {
            case .sum:
                _stats = .init(sampleType, aggregatedBy: [.sum], over: chartConfig.aggregationInterval, timeRange: .today)
            case .average:
                _stats = .init(sampleType, aggregatedBy: [.average], over: chartConfig.aggregationInterval, timeRange: .today)
            }
        } else {
            // we don't have a chart, ie we just want to display the total / most recent value
            switch aggregationKind {
            case .sum:
                _stats = .init(sampleType, aggregatedBy: [.sum], over: .day, timeRange: .today)
            case .average:
                _stats = .init(sampleType, aggregatedBy: [.average], over: .day, timeRange: .today)
            }
        }
    }
    
    var body: some View {
        SmallGridCell(title: sampleType.displayTitle) {
            if aggregationKind == .sum, let dailyTotalGoal, dailyTotalGoal > 0 {
                let currentTotal = stats.reduce(into: 0) { total, stats in
                    if let value = stats.sumQuantity()?.doubleValue(for: $stats.sampleType.displayUnit) {
                        total += value
                    }
                }
                CircularProgressView(currentTotal / dailyTotalGoal, lineWidth: 2.5, showProgressAsLabel: true)
                    .tint(sampleType.preferredTintColorForDisplay)
                    .frame(height: 27)
                    .font(.system(size: 7))
            }
        } content: {
            if let chartConfig {
                ChartView(stats: $stats, config: chartConfig, aggregationKind: aggregationKind)
            } else {
                nonChartContent
            }
        }
    }
    
    private var nonChartContent: some View {
        struct Content {
            let value: Double
            let sampleType: SampleType<HKQuantitySample>
            let date: Date
        }
        func formatValue(_ value: Double, for sampleType: SampleType<HKQuantitySample>) -> String { // TODO sampleType instead of unit?!
            switch sampleType {
            case .bloodOxygen:
                return String(format: "%.1f", value / 100)
            case .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage:
                return String(format: "%.2f", value / 100)
            case _ where sampleType.displayUnit == .count():
                return String(Int(value))
            default:
                if value.isWholeNumber {
                    return String(Int(value))
                } else {
                    return String(format: "%.2f", value)
                }
            }
        }
        @ViewBuilder
        func makeView(for content: Content?) -> some View {
            if let content {
                VStack {
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(formatValue(content.value, for: content.sampleType))
                            .font(.title.bold().monospacedDigit())
                        Text(content.sampleType.displayUnit.unitString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(content.date, style: .time)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            } else {
                Text("n/a") // TODO!!!
            }
        }
        
        let content: Content?
        switch aggregationKind {
        case .sum:
            if let dateInterval = stats.last?.mostRecentQuantityDateInterval() {
                content = .init(value: dailyTotal, sampleType: sampleType, date: dateInterval.end)
            } else {
                content = nil
            }
        case .average:
            // in the case of an average-based aggregation, i.e. in the case of all non-cumulative sample types,
            // we instead display the most recent sample
            if let mostRecentQuantity = stats.last?.mostRecentQuantity(), let dateInterval = stats.last?.mostRecentQuantityDateInterval() {
                content = .init(value: mostRecentQuantity.doubleValue(for: sampleType.displayUnit), sampleType: sampleType, date: dateInterval.end)
            } else {
                content = nil
            }
        }
        return makeView(for: content)
    }
    
    
    private var dailyTotal: Double {
        stats.reduce(into: 0) { total, stats in
            if let value = stats.sumQuantity()?.doubleValue(for: sampleType.displayUnit) {
                total += value
            }
        }
    }
}


extension QuantityHealthStatGridCell {
    struct ChartConfig: Hashable, Sendable {
        let mode: HealthChartDrawingConfig.Mode
        let aggregationInterval: HealthKitStatisticsQuery.AggregationInterval
        
        init(mode: HealthChartDrawingConfig.Mode, aggregationInterval: HealthKitStatisticsQuery.AggregationInterval = .hour) {
            self.mode = mode
            self.aggregationInterval = aggregationInterval
        }
    }
    
    struct ChartView: View {
        @Environment(\.calendar) private var calendar
        private var stats: StatisticsQueryResults
        private let config: ChartConfig
        private let chartTint: Color
        private let aggregationKind: QuantityHealthStatGridCell.AggregationKind
        
        init(stats: StatisticsQueryResults, config: ChartConfig, aggregationKind: QuantityHealthStatGridCell.AggregationKind) {
            self.stats = stats
            self.config = config
            self.chartTint = stats.sampleType.preferredTintColorForDisplay ?? .orange
            self.aggregationKind = aggregationKind
        }
        
        var body: some View {
            chart
                .frame(height: 80)
        }
        
        @ViewBuilder
        private var chart: some View {
            Chart(stats) { stats in
                let quantity: HKQuantity? = switch aggregationKind {
                case .sum:
                    stats.sumQuantity()
                case .average:
                    stats.averageQuantity()
                }
                if let value = quantity?.doubleValue(for: self.stats.sampleType.displayUnit) {
                    let x: PlottableValue = .value("Date", stats.startDate..<stats.endDate)
                    let y: PlottableValue = .value(self.stats.sampleType.displayTitle, value)
                    switch config.mode {
                    case .bar:
                        BarMark(x: x, y: y)
                            .foregroundStyle(chartTint)
                    case .line:
                        LineMark(x: x, y: y)
                            .foregroundStyle(chartTint)
                            .interpolationMethod(.catmullRom)
                    case .point:
                        PointMark(x: x, y: y)
                            .symbolSize(10)
                            .foregroundStyle(chartTint)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartYAxis(.hidden)
    //        .chartXAxis(content: <#T##() -> AxisContent#>)
            .chartXScale(domain: [Date.today, Date.tomorrow])
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    if let date = value.as(Date.self) {
                        let hour = calendar.component(.hour, from: date)
                        switch hour {
                        case 0, 12:
                            AxisValueLabel(format: .dateTime.hour())
                        default:
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYAxis {
                AxisMarks(values: [0]) {
                    AxisGridLine()
                }
            }
        }
    }
}




extension QuantityHealthStatGridCell.ChartConfig {
    static func `default`(for sampleType: SampleType<HKQuantitySample>) -> Self {
        switch sampleType {
        case .stepCount, .activeEnergyBurned:
            .init(mode: .bar)
        case .distanceWalkingRunning:
            .init(mode: .line)
        case .heartRate:
            .init(mode: .point, aggregationInterval: .init(.init(minute: 15)))
        case .bloodOxygen:
            .init(mode: .point)
        default:
            .init(mode: .line)
        }
    }
}

extension FloatingPoint {
    var isWholeNumber: Bool {
        rounded() == self // TODO is this correct? a good idea?
    }
}



/// Compare two sample types, based on their identifiers
@inlinable public func ~= (pattern: SampleType<some Any>, value: SampleTypeProxy) -> Bool {
    pattern.id == value.id
}

///// Compare two sample types, based on their identifiers
//@_disfavoredOverload
//@inlinable public func ~= (pattern: SampleType<some Any>, value: any AnySampleType) -> Bool {
//    pattern.id == value.id
//}


extension AnySampleType {
    var preferredTintColorForDisplay: Color? {
        switch SampleTypeProxy(self) {
        case .heartRate, .activeEnergyBurned:
            Color.red
        case .bloodOxygen:
            Color.blue
        case .bloodPressure, .bloodPressureSystolic, .bloodPressureDiastolic:
            Color.red
        case .stepCount, .walkingStepLength, .distanceWalkingRunning, .runningStrideLength, .stairAscentSpeed, .stairDescentSpeed, .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage:
            Color.orange
        default:
            nil
        }
    }
}
