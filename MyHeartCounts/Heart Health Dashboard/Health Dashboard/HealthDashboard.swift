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



struct StyledGauge: View {
    @State private var current = 67.0
    @State private var minValue = 50.0
    @State private var maxValue = 170.0
    let gradient = Gradient(colors: [.green, .yellow, .orange, .red])


    var body: some View {
        SwiftUI.Gauge(value: current, in: minValue...maxValue) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
        } currentValueLabel: {
            Text("\(Int(current))")
                .foregroundColor(Color.green)
        } minimumValueLabel: {
            Text("\(Int(minValue))")
                .foregroundColor(Color.green)
        } maximumValueLabel: {
            Text("\(Int(maxValue))")
                .foregroundColor(Color.red)
        }
        .gaugeStyle(.accessoryCircular)
//        .gaugeStyle(CircularGaugeStyle(tint: gradient))
    }
}



struct HealthDashboard: View {
    @Environment(HeartHealthManager.self)
    private var manager: HeartHealthManager?
    
    let layout: HealthDashboardLayout
    
    var body: some View {
        ScrollView {
//            Section {
//                Color.clear.frame(height: 20)
//                HStack {
//                    Spacer()
//                    StyledGauge()
//                        .frame(width: 40, height: 40)
//                    Spacer()
//                    Gauge(progress: 0.71, gradient: Gradient(colors: [.green, .yellow, .orange, .red]), backgroundColor: .clear, lineWidth: 4)
//                        .frame(width: 40, height: 40)
//                    Spacer()
//                }
//            }
            ForEach(0..<layout.blocks.endIndex, id: \.self) { blockIdx in
                let block = layout.blocks[blockIdx]
                Section {
                    switch block.content {
                    case .large(let component):
                        makeChart(for: component)
                    case .grid(let components):
                        makeGrid(with: components)
                    }
                } header: {
                    if let title = block.title {
                        HStack {
                            Text(title)
                                .font(.title3.bold())
                            Spacer()
                        }
                        .padding(.top, 17)
                    }
                }
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
            ForEach(0..<components.endIndex, id: \.self) { idx in
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
                dailyTotalGoal: manager?.goals[sampleType],
                timeRange: component.timeRange,
                chartConfig: component.chartConfig
            )
        case .category(.sleepAnalysis):
            SleepAnalysisGridCell()
        case .correlation(.bloodPressure):
            BloodPressureGridCell()
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func makeChart(
        for component: HealthDashboardLayout.LargeChartComponent
    ) -> some View {
//        let config = component.chartConfig.resolved(for: sampleType, in: timeRange)
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
    private let timeRange: HealthKitQueryTimeRange
    private let chartConfig: ResolvedChartConfig?
    private let aggregationKind: AggregationKind
    private let dailyTotalGoal: Double? // TODO also support a weekly total? would we have a use case for that?
    @HealthKitStatisticsQuery private var stats: [HKStatistics] // TODO the type shouldn't be necessary here!
    
    init(_ sampleType: SampleType<HKQuantitySample>, dailyTotalGoal: HKQuantity?, timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig?) {
        self.init(
            sampleType,
            dailyTotalGoal: dailyTotalGoal?.doubleValue(for: sampleType.displayUnit),
            timeRange: timeRange,
            chartConfig: chartConfig
        )
    }
    
    init(_ sampleType: SampleType<HKQuantitySample>, dailyTotalGoal: Double? = nil, timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig?) {
        self.sampleType = sampleType
        self.timeRange = timeRange
        self.chartConfig = chartConfig?.resolved(for: sampleType, in: timeRange)
        self.dailyTotalGoal = dailyTotalGoal
        self.aggregationKind = .init(sampleType.hkSampleType.aggregationStyle)
        if let chartConfig = self.chartConfig {
            switch aggregationKind {
            case .sum:
                _stats = .init(sampleType, aggregatedBy: [.sum], over: chartConfig.aggregationInterval, timeRange: timeRange)
            case .average:
                _stats = .init(sampleType, aggregatedBy: [.average], over: chartConfig.aggregationInterval, timeRange: timeRange)
            }
        } else {
            // we don't have a chart, ie we just want to display the total / most recent value
            switch aggregationKind {
            case .sum:
                // TODO .day won't necessarily be correct anymore, if timeRange != .today!
                _stats = .init(sampleType, aggregatedBy: [.sum], over: .day, timeRange: timeRange)
            case .average:
                // TODO .day won't necessarily be correct anymore, if timeRange != .today!
                _stats = .init(sampleType, aggregatedBy: [.average], over: .day, timeRange: timeRange)
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
//        struct Content {
//            let value: Double
//            let sampleType: SampleType<HKQuantitySample>
//            let date: Date
//        }
//        func formatValue(_ value: Double, for sampleType: SampleType<HKQuantitySample>) -> String { // TODO sampleType instead of unit?!
//            switch sampleType {
//            case .bloodOxygen:
//                return String(format: "%.1f", value / 100)
//            case .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage:
//                return String(format: "%.2f", value / 100)
//            case _ where sampleType.displayUnit == .count():
//                return String(Int(value))
//            default:
//                if value.isWholeNumber {
//                    return String(Int(value))
//                } else {
//                    return String(format: "%.2f", value)
//                }
//            }
//        }
        @ViewBuilder
        func makeView(for input: QuantityLabel.Input?) -> some View {
            if let input {
                QuantityLabel(input: input)
            } else {
                Text("n/a") // TODO!!!
            }
        }
        
        let input: QuantityLabel.Input?
        switch aggregationKind {
        case .sum:
            if let dateInterval = stats.last?.mostRecentQuantityDateInterval() {
                input = .init(value: dailyTotal, sampleType: sampleType, date: dateInterval.end)
            } else {
                input = nil
            }
        case .average:
            // in the case of an average-based aggregation, i.e. in the case of all non-cumulative sample types,
            // we instead display the most recent sample
            if let mostRecentQuantity = stats.last?.mostRecentQuantity(), let dateInterval = stats.last?.mostRecentQuantityDateInterval() {
                input = .init(value: mostRecentQuantity.doubleValue(for: sampleType.displayUnit), sampleType: sampleType, date: dateInterval.end)
            } else {
                input = nil
            }
        }
        return makeView(for: input)
    }
    
    
    private var dailyTotal: Double {
        stats.reduce(into: 0) { total, stats in
            if let value = stats.sumQuantity()?.doubleValue(for: sampleType.displayUnit) {
                total += value
            }
        }
    }
    
    
    
    struct QuantityLabel: View {
        struct Input {
            let valueString: String
            let unitString: String
            let date: Date
            
            init(valueString: String, unitString: String, date: Date) {
                self.valueString = valueString
                self.unitString = unitString
                self.date = date
            }
            
            init(value: Double, sampleType: SampleType<HKQuantitySample>, date: Date) {
                self.valueString = switch sampleType {
                case .bloodOxygen:
                    String(format: "%.1f", value / 100)
                case .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage:
                    String(format: "%.2f", value / 100)
                case _ where sampleType.displayUnit == .count():
                    String(Int(value))
                default:
                    if value.isWholeNumber {
                        String(Int(value))
                    } else {
                        String(format: "%.2f", value)
                    }
                }
                self.unitString = sampleType.displayUnit.unitString
                self.date = date
            }
        }
        
        let input: Input
        
        var body: some View {
            VStack {
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(input.valueString)
                        .font(.title.bold())
                    Text(input.unitString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(input.date, style: .time)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }
}


extension QuantityHealthStatGridCell {
    struct ChartConfig: Hashable, Sendable {
        private enum Variant: Hashable, Sendable {
            case resolved(ResolvedChartConfig)
            case automatic
        }
        
        private let variant: Variant
        
        private init(variant: Variant) {
            self.variant = variant
        }
        
        init(mode: HealthChartDrawingConfig.Mode, aggregationInterval: HealthKitStatisticsQuery.AggregationInterval /*= .hour*/) {
            self.init(variant: .resolved(.init(mode: mode, aggregationInterval: aggregationInterval)))
        }
        
        static var automatic: ChartConfig {
            Self(variant: .automatic)
        }
        
        fileprivate func resolved(for sampleType: SampleType<HKQuantitySample>, in timeRange: HealthKitQueryTimeRange) -> ResolvedChartConfig {
            switch variant {
            case .resolved(let resolved):
                resolved
            case .automatic:
                ResolvedChartConfig.default(for: sampleType, in: timeRange)
            }
        }
    }
    
    fileprivate struct ResolvedChartConfig: Hashable, Sendable {
        let mode: HealthChartDrawingConfig.Mode
        let aggregationInterval: HealthKitStatisticsQuery.AggregationInterval
    }
    
    private struct ChartView: View {
        @Environment(\.calendar) private var calendar
        private var stats: StatisticsQueryResults
        private let config: ResolvedChartConfig
        private let chartTint: Color
        private let aggregationKind: QuantityHealthStatGridCell.AggregationKind
        
        init(stats: StatisticsQueryResults, config: ResolvedChartConfig, aggregationKind: QuantityHealthStatGridCell.AggregationKind) {
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
            .chartOverlay { _ in
                if stats.isEmpty {
                    Text("No data")
                        .foregroundStyle(.secondary)
                }
            }
            .chartLegend(.hidden)
//            .chartYAxis(.hidden)
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
//                AxisMarks(values: [0]) {
//                    AxisGridLine()
//                }
                AxisMarks(values: .automatic(desiredCount: 3))
            }
        }
        
//        @ChartContentBuilder private var trendline: some ChartContent {
//            
//        }
    }
}




extension QuantityHealthStatGridCell.ResolvedChartConfig {
    fileprivate static func `default`(for sampleType: SampleType<HKQuantitySample>, in timeRange: HealthKitQueryTimeRange) -> Self {
        let defaultAggIterval = defaultSmallChartAggregationInterval(for: timeRange)
        return switch sampleType {
        case .stepCount, .activeEnergyBurned:
            .init(mode: .bar, aggregationInterval: defaultAggIterval)
        case .distanceWalkingRunning:
            .init(mode: .line, aggregationInterval: defaultAggIterval)
        case .heartRate:
            .init(mode: .point, aggregationInterval: .init(.init(minute: 15)))
        case .bloodOxygen:
            .init(mode: .point, aggregationInterval: defaultAggIterval)
        default:
            .init(mode: .line, aggregationInterval: defaultAggIterval)
        }
    }
    
    private static func defaultSmallChartAggregationInterval(for timeRange: HealthKitQueryTimeRange) -> HealthKitStatisticsQuery.AggregationInterval {
        let duration = timeRange.duration
        return if duration <= TimeConstants.hour {
            HealthKitStatisticsQuery.AggregationInterval(.init(minute: 15))
        } else if duration <= TimeConstants.day / 2 {
            .init(.init(hour: 2))
        } else if duration <= TimeConstants.day {
            .hour
        } else if duration <= TimeConstants.day * 4 {
            .init(.init(hour: 12))
        } else if duration <= TimeConstants.week * 2 {
            .day
        } else if duration <= TimeConstants.month {
            .init(.init(day: 2))
        } else {
            .week
        }
    }
}


enum TimeConstants {
    static let minute: TimeInterval = 60
    static let hour = 60 * minute
    static let day = 24 * hour
    static let week = 7 * day
    static let month = 31 * day
    static let year = 365 * day
}


extension FloatingPoint {
    var isWholeNumber: Bool {
        rounded() == self // TODO is this correct? a good idea?
    }
}




struct SleepAnalysisGridCell: View {
    @HealthKitQuery(.sleepAnalysis, timeRange: .last(days: 4))
    private var sleepAnalysis
    
    var body: some View {
        let sleepSessions = try! sleepAnalysis.splitIntoSleepSessions() // swiftlint:disable:this force_try
        
        SmallGridCell(title: $sleepAnalysis.sampleType.displayTitle) {
            EmptyView() // TODO?
        } content: {
            if let session = sleepSessions.last {
                QuantityHealthStatGridCell.QuantityLabel(input: .init(
                    valueString: String(format: "%.1f", session.totalTimeAsleep / 60 / 60),
                    unitString: HKUnit.hour().unitString,
                    date: session.endDate
                ))
            }
        }
    }
}

struct BloodPressureGridCell: View {
    @HealthKitQuery(.bloodPressure, timeRange: .last(months: 6))
    private var samples
    
    var body: some View {
        SmallGridCell(title: $samples.sampleType.displayTitle) {
            EmptyView() // TODO?
        } content: {
            if let sample = samples.last,
               let systolic = sample.firstSample(ofType: .bloodPressureSystolic),
               let diastolic = sample.firstSample(ofType: .bloodPressureDiastolic) {
                let unit = SampleType.bloodPressureSystolic.displayUnit
                QuantityHealthStatGridCell.QuantityLabel(input: .init(
                    valueString: "\(Int(systolic.quantity.doubleValue(for: unit)))/\(Int(diastolic.quantity.doubleValue(for: unit)))",
                    unitString: unit.unitString,
                    date: sample.endDate
                ))
            }
        }
    }
}


extension HKCorrelation {
    func firstSample<Sample>(ofType sampleType: SampleType<Sample>) -> Sample? {
        for sample in self.objects {
            if let sample = sample as? Sample, sample.is(sampleType) {
                return sample
            }
        }
        return nil
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
