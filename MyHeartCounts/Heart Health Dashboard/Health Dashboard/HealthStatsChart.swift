//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Charts
import Foundation
import SpeziFoundation
import SpeziHealthKitUI
import SwiftUI


struct ChartDataSetDrawingConfig: Sendable {
    /// A chart type.
    enum ChartType: Sendable {
        /// The entry is drawn as a line chart, i.e. a line that moves from data point to data point
        case line(interpolationMethod: InterpolationMethod = .linear)
        /// bar chart
        case bar
        /// each data point is its own point in the chart, not connected to anything else
        case point(area: Double? = 10)
    }
    
    let chartType: ChartType
    let color: Color
    
    /// Creates a new drawing config for an entry in a health chart.
    init(chartType: ChartType, color: Color) {
        self.chartType = chartType
        self.color = color
    }
}


struct HealthStatsChartDataPoint: Hashable, Sendable {
    let timeRange: Range<Date>
    let value: Double
    
    init(timeRange: Range<Date>, value: Double) {
        self.timeRange = timeRange
        self.value = value
    }
    
    init(date: Date, value: Double) {
        self.init(
            timeRange: date..<date,
            value: value
        )
    }
}


protocol HealthStatsChartDataSetProtocol<Data> {
    associatedtype Data: RandomAccessCollection
    associatedtype ID: Hashable
    
    var name: String { get }
    
    var drawingConfig: ChartDataSetDrawingConfig { get }
    var data: Data { get }
    var id: KeyPath<Data.Element, ID> { get }
    var makeDataPoint: (Data.Element) -> HealthStatsChartDataPoint? { get }
}


struct HealthStatsChartDataSet<Data: RandomAccessCollection, ID: Hashable>: HealthStatsChartDataSetProtocol {
    let name: String
    let drawingConfig: ChartDataSetDrawingConfig
    let data: Data
    let id: KeyPath<Data.Element, ID>
    let makeDataPoint: (Data.Element) -> HealthStatsChartDataPoint?
    
    init(
        name: String,
        drawingConfig: ChartDataSetDrawingConfig,
        data: Data,
        id: KeyPath<Data.Element, ID>,
        makeDataPoint: @escaping (Data.Element) -> HealthStatsChartDataPoint?
    ) {
        self.name = name
        self.drawingConfig = drawingConfig
        self.data = data
        self.id = id
        self.makeDataPoint = makeDataPoint
    }
    
    init(
        name: String,
        drawingConfig: ChartDataSetDrawingConfig,
        dataPoints: Data
    ) where Data.Element == HealthStatsChartDataPoint, ID == HealthStatsChartDataPoint {
        self.init(name: name, drawingConfig: drawingConfig, data: dataPoints, id: \.self, makeDataPoint: { $0 })
    }
}


struct HealthStatsChart<each DataSet: HealthStatsChartDataSetProtocol>: View {
    @Environment(\.calendar)
    private var calendar
    @Environment(\.healthStatsChartHoverHighlightEnabled)
    private var enableHoverHighlight
    
    private let dataSet: (repeat each DataSet)
    
    @State private var xSelection: Date?
    
    private var hasData: Bool {
        for dataSet in repeat each dataSet {
            if !dataSet.data.isEmpty { // swiftlint:disable:this for_where
                return true
            }
        }
        return false
    }
    
    var body: some View {
        chart
            .chartOverlay { _ in
                if !hasData {
                    Text("No Data")
                }
            }
    }
    
    @ViewBuilder private var chart: some View {
        Chart {
            chartContent
        }
        .chartLegend(.hidden)
        .if(enableHoverHighlight) {
            $0.chartXSelection(value: $xSelection)
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3))
        }
    }
    
    
    @ChartContentBuilder private var chartContent: some ChartContent {
        ChartContentBuilder.buildBlock(repeat buildContent(for: each dataSet))
        if enableHoverHighlight,
           let xSelection,
           case let dataPoints = xAxisSelectionDataPoints(for: xSelection),
           let (_, dataPoint) = dataPoints.last {
            ChartHighlightRuleMark(
                x: .value("Selection", xSelection, unit: .day, calendar: calendar),
                primaryText: "\(dataPoint.value)", // unit?
                secondaryText: dataPoint.timeRange.middle.formatted(.dateTime)
            )
        }
    }
    
    init(_ dataSet: repeat each DataSet) {
        self.dataSet = (repeat each dataSet)
    }
    
    @ChartContentBuilder
    private func buildContent(for dataSet: some HealthStatsChartDataSetProtocol) -> some ChartContent {
        ForEach(dataSet.data, id: dataSet.id) { element in
            if let dataPoint = dataSet.makeDataPoint(element) {
                chartContent(for: dataPoint, in: dataSet)
            }
        }
    }
    
    @ChartContentBuilder
    private func chartContent(for dataPoint: HealthStatsChartDataPoint, in dataSet: some HealthStatsChartDataSetProtocol) -> some ChartContent {
        let xVal: PlottableValue = .value("Date", dataPoint.timeRange)
        let yVal: PlottableValue = .value(dataSet.name, dataPoint.value)
        let series: PlottableValue = .value("Series", dataSet.name)
        SomeChartContent {
            switch dataSet.drawingConfig.chartType {
            case let .line(interpolationMethod):
                LineMark(x: xVal, y: yVal, series: series)
                    .interpolationMethod(interpolationMethod)
            case .bar:
                BarMark(x: xVal, y: yVal)
            case let .point(area):
                PointMark(x: xVal, y: yVal)
                    .if(area) { $1.symbolSize($0) }
            }
        }
        .foregroundStyle(dataSet.drawingConfig.color)
    }
    
    private func xAxisSelectionDataPoints(for selection: Date) -> [(any HealthStatsChartDataSetProtocol, HealthStatsChartDataPoint)] {
        var retval: [(any HealthStatsChartDataSetProtocol, HealthStatsChartDataPoint)] = []
        for dataSet in repeat each dataSet {
            let dataPoints = dataSet.data.lazy.compactMap(dataSet.makeDataPoint)
            for dataPoint in dataPoints.filter({ $0.timeRange.contains(selection) }) {
                retval.append((dataSet, dataPoint))
            }
        }
        return retval
    }
}


// MARK: Environment Values

extension EnvironmentValues {
    @Entry fileprivate var healthStatsChartHoverHighlightEnabled: Bool = false
}

extension View {
    func healthStatsChartHoverHighlightEnabled(_ isEnabled: Bool = true) -> some View {
        self.environment(\.healthStatsChartHoverHighlightEnabled, isEnabled)
    }
}


// MARK: Other


private struct ChartXAxisModifier: ViewModifier {
    @Environment(\.calendar)
    private var cal
    
    let timeRange: Range<Date>
    
    func body(content: Content) -> some View {
        content.chartXAxis {
            let duration = timeRange.timeInterval
            let daysStride = if duration <= TimeConstants.week {
                1
            } else if duration <= TimeConstants.month {
                7
            } else {
                14
            }
            AxisMarks(values: .stride(by: .day, count: daysStride)) { value in
                if let date = value.as(Date.self) {
                    if let prevDate = cal.date(byAdding: .day, value: -daysStride, to: date) {
                        let format: Date.FormatStyle = .dateTime.omittingTime()
                            .year(cal.isDate(prevDate, equalTo: date, toGranularity: .year) ? .omitted : .defaultDigits)
                            .month(cal.isDate(prevDate, equalTo: date, toGranularity: .month) ? .omitted : .defaultDigits)
                        AxisValueLabel(format: format)
                    } else {
                        AxisValueLabel(format: .dateTime.omittingTime())
                    }
                }
                AxisGridLine()
                AxisTick()
            }
        }
    }
}

extension View {
    func configureChartXAxisWithDailyMarks(forTimeRange timeRange: Range<Date>) -> some View {
        self.modifier(ChartXAxisModifier(timeRange: timeRange))
    }
}
