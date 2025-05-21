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
import SpeziHealthKitUI
import SwiftUI


public struct ChartDataSetDrawingConfig: Sendable {
    /// A chart type.
    public enum ChartType: Sendable {
        /// The entry is drawn as a line chart, i.e. a line that moves from data point to data point
        case line(interpolationMethod: InterpolationMethod = .linear)
        /// bar chart
        case bar
        /// each data point is its own point in the chart, not connected to anything else
        case point(area: Double? = 10)
    }
    
    public let chartType: ChartType
    public let color: Color
    
    /// Creates a new drawing config for an entry in a health chart.
    public init(chartType: ChartType, color: Color) {
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
    @Environment(\.calendar) private var calendar
    
    private let dataSet: (repeat each DataSet)
    
    init(
        _ dataSet: repeat each DataSet
    ) {
        self.dataSet = (repeat each dataSet)
    }
    
    
    private var hasData: Bool {
        for dataSet in repeat each dataSet {
            if !dataSet.data.isEmpty {
                return true
            }
        }
        return false
    }
    
    var body: some View {
        chart
            .frame(height: 80)
            .chartOverlay { _ in
                if !hasData {
                    // TODO make this look nice!
                    Text("No Data")
                }
            }
    }
    
    @ViewBuilder private var chart: some View {
        Chart {
            chartContent
        }
        .chartLegend(.hidden)
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
            AxisMarks(values: .automatic(desiredCount: 3))
        }
    }
    
    
    private var chartContent: some ChartContent {
        ChartContentBuilder.buildBlock(repeat buildContent(for: each dataSet))
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
}


// TODO we now have this here and in SpeziHealthKitUI; maybe move it into SpeziViews?!
struct SomeChartContent<Body: ChartContent>: ChartContent { // swiftlint:disable:this file_types_order
    private let content: @MainActor () -> Body
    
    var body: some ChartContent {
        content()
    }
    
    init(@ChartContentBuilder _ content: @escaping @MainActor () -> Body) {
        self.content = content
    }
}


extension ChartContent {
    @ChartContentBuilder
    func `if`<T>(_ value: T?, @ChartContentBuilder _ makeContent: (T, Self) -> some ChartContent) -> some ChartContent {
        if let value {
            makeContent(value, self)
        } else {
            self
        }
    }
}
