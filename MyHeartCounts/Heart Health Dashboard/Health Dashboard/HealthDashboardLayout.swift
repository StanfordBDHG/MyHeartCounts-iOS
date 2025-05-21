//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


enum HealthDashboardLayoutBuilder: RangeReplaceableCollectionBuilderBase {
    typealias Element = HealthDashboardLayout.Block
    
    static func buildFinalResult(_ component: IntermediateStep) -> HealthDashboardLayout {
        HealthDashboardLayout(blocks: component)
    }
}

struct HealthDashboardLayout: Sendable {
    var blocks: [Block]
    
    init(blocks: some Collection<Block> = []) {
        self.blocks = Array(blocks)
    }
}


extension HealthDashboardLayout {
    enum ComponentSize {
        case large
        case small
    }
    
    struct Block: Sendable {
        enum Content: Sendable {
            case largeChart(LargeChartComponent)
            case largeCustom(@MainActor () -> AnyView)
            case grid([GridComponent])
        }
        
        let title: String? // TODO localize!
        let content: Content
        
        private init(title: String?, content: Content) {
            self.title = title
            self.content = content
        }
        
        static func largeChart(
            sectionTitle: String?,
            component: LargeChartComponent
        ) -> Self {
            .init(title: sectionTitle, content: .largeChart(component))
        }
        
        static func large(
            sectionTitle: String?,
            @ViewBuilder content: @MainActor @escaping () -> some View
        ) -> Self {
            .init(title: sectionTitle, content: .largeCustom {
                content().intoAnyView()
            })
        }
        
        static func grid(sectionTitle: String, components: [GridComponent]) -> Self {
            .init(title: sectionTitle, content: .grid(components))
        }
        
        static func grid(sectionTitle: String, @ArrayBuilder<GridComponent> components: () -> [GridComponent]) -> Self {
            .init(title: sectionTitle, content: .grid(components()))
        }
    }
}


// MARK: Styles and related Configs

extension HealthDashboardLayout {
    enum Style: Sendable {
        case singleValue(SingleValueConfig)
        case chart(ChartConfig)
        case gauge(GaugeConfig) // TODO need to specify the min/max values, and what we want to use as the "current" value (ie: latest? average?)
        
        func effectiveAggregationKind(for sampleType: MHCQuantitySampleType) -> StatisticsQueryAggregationKind {
            switch self {
            case .chart:
                StatisticsQueryAggregationKind(sampleType)
            case .singleValue(let config), .gauge(let config):
                config.effectiveAggregationKind ?? .init(sampleType)
            }
        }
    }
    
    /// How the gauge's "current value" should be determined
    typealias GaugeConfig = SingleValueConfig
    
    struct SingleValueConfig: Sendable {
        enum _Variant: Sendable { // swiftlint:disable:this type_name
            case mostRecentSample
            case aggregated([QuantitySamplesAggregationStrategy], StatisticsQueryAggregationKind?)
        }
        let _variant: _Variant // swiftlint:disable:this identifier_name
        
        private init(_variant: _Variant) {
            self._variant = _variant
        }
        
        fileprivate var effectiveAggregationKind: StatisticsQueryAggregationKind? {
            switch _variant {
            case .mostRecentSample:
                nil
            case .aggregated(let steps, let final):
                final ?? steps.last!.kind // swiftlint:disable:this force_unwrapping
            }
        }
        
        static var mostRecentSample: Self {
            .init(_variant: .mostRecentSample)
        }
        
        static func aggregated(_ kind: StatisticsQueryAggregationKind) -> Self {
            .init(_variant: .aggregated([], kind))
        }
        
        static func aggregated(_ strategy1: QuantitySamplesAggregationStrategy, _ additional: QuantitySamplesAggregationStrategy...) -> Self {
            .init(_variant: .aggregated([strategy1].appending(contentsOf: additional), nil))
        }
        
        static func aggregated(
            _ start: QuantitySamplesAggregationStrategy,
            _ final: StatisticsQueryAggregationKind
        ) -> Self {
            .aggregated(start, final: final)
        }
        
        static func aggregated(
            _ start: QuantitySamplesAggregationStrategy,
            _ then: QuantitySamplesAggregationStrategy...,
            final: StatisticsQueryAggregationKind
        ) -> Self {
            .init(_variant: .aggregated([start].appending(contentsOf: then), final))
        }
    }
    
    
    struct ChartConfig: Sendable {
        let chartType: ChartDataSetDrawingConfig.ChartType
        let aggregationInterval: HealthKitStatisticsQuery.AggregationInterval
        
        fileprivate static func `default`(for sampleType: SampleType<HKQuantitySample>, in timeRange: HealthKitQueryTimeRange) -> Self {
            let defaultAggIterval = defaultSmallChartAggregationInterval(for: timeRange)
            return switch sampleType {
            case .stepCount, .activeEnergyBurned:
                .init(chartType: .bar, aggregationInterval: defaultAggIterval)
            case .distanceWalkingRunning:
                .init(chartType: .line(), aggregationInterval: defaultAggIterval)
            case .heartRate:
                .init(chartType: .point(), aggregationInterval: .init(.init(minute: 15)))
            case .bloodOxygen:
                .init(chartType: .point(), aggregationInterval: defaultAggIterval)
            default:
                .init(chartType: .line(), aggregationInterval: defaultAggIterval)
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
    
    struct AutomaticChartConfig {
        private init() {}
        static let automatic = Self()
    }
    
    
    protocol CustomDataSourceProtocol: Sendable, Observable, RandomAccessCollection where Element == QuantitySample {
        /// The range of time represented by this data source
        var timeRange: HealthKitQueryTimeRange { get }
        var sampleType: CustomQuantitySampleType { get }
    }
    
    enum DataSource: Sendable {
        case healthKit(SampleTypeProxy)
        case custom(any CustomDataSourceProtocol)
        
        var sampleTypeDisplayTitle: String {
            switch self {
            case .healthKit(let sampleType):
                sampleType.underlyingSampleType.displayTitle
            case .custom(let dataSource):
                dataSource.sampleType.displayTitle
            }
        }
    }
    
    
    struct LargeChartComponent: Sendable {
        let dataSource: DataSource
        let timeRange: HealthKitQueryTimeRange
        let chartConfig: ChartConfig
        
        private init(dataSource: DataSource, timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig) {
            self.dataSource = dataSource
            self.timeRange = timeRange
            self.chartConfig = chartConfig
        }
        
        init(sampleType: SampleType<HKQuantitySample>, timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig) {
            self.init(dataSource: .healthKit(SampleTypeProxy(sampleType)), timeRange: timeRange, chartConfig: chartConfig)
        }
        init(sampleType: SampleType<HKQuantitySample>, timeRange: HealthKitQueryTimeRange, chartConfig: AutomaticChartConfig) {
            self.init(
                dataSource: .healthKit(SampleTypeProxy(sampleType)),
                timeRange: timeRange,
                chartConfig: .default(for: sampleType, in: timeRange)
            )
        }
    }
    
    
    /// A Health Stat Component within a Grid Section
    enum GridComponent: Sendable {
        /// The config of a component that displays a Quantity fetched from eg HealthKit.
        struct QuantityDisplayComponentConfig: Sendable {
            let dataSource: DataSource
            let timeRange: HealthKitQueryTimeRange
            let style: Style
            let allowAddingSamples: Bool
        }
        
        /// The config of a component that displays a custom view.
        struct CustomComponentConfig: Sendable {
            let title: String
            let content: @MainActor () -> AnyView
            let tapAction: (@MainActor () -> Void)?
            
            fileprivate init(title: String, content: @MainActor @escaping () -> AnyView, tapAction: (@MainActor () -> Void)?) {
                self.title = title
                self.content = content
                self.tapAction = tapAction
            }
        }
        
        case quantityDisplay(QuantityDisplayComponentConfig)
        case custom(CustomComponentConfig)
        
        private init(dataSource: DataSource, timeRange: HealthKitQueryTimeRange, style: Style, allowAddingSamples: Bool) {
            self = .quantityDisplay(.init(dataSource: dataSource, timeRange: timeRange, style: style, allowAddingSamples: allowAddingSamples))
        }
        
        /// Creates a new Component
        /// - parameter sampleType: The `SampleType` the component should visualise.
        /// - parameter timeRange: The time range for which the component should visualise data.
        /// - parameter chartConfig: Whether the component should use a chart to visualize its data, and what the chart should look like.
        init(
            _ sampleType: SampleType<HKQuantitySample>,
            timeRange: HealthKitQueryTimeRange = .today, // swiftlint:disable:this function_default_parameter_at_end
            style: Style,
            allowAddingSamples: Bool = true // TODO default back to false!
        ) {
            self = .quantityDisplay(.init(
                dataSource: .healthKit(SampleTypeProxy(sampleType)),
                timeRange: timeRange,
                style: style,
                allowAddingSamples: allowAddingSamples
            ))
        }
        
        static func bloodPressure(style: Style) -> Self {
            Self(dataSource: .healthKit(.init(.bloodPressure)), timeRange: .last(days: 2), style: style, allowAddingSamples: false)
        }
        
        static func sleepAnalysis(style: Style) -> Self {
            Self(dataSource: .healthKit(.init(.sleepAnalysis)), timeRange: .last(days: 7), style: style, allowAddingSamples: false)
        }
        
        static func custom(
            title: String
            /*, dataSource: DataSource?*/,
            @ViewBuilder _ content: @MainActor @escaping () -> some View,
            onTap tapAction: (@MainActor () -> Void)? = nil
        ) -> Self {
            .custom(.init(
                title: title,
                content: { content().intoAnyView() },
                tapAction: tapAction
            ))
        }
    }
}


extension HealthDashboardLayout: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Block...) {
        self.init(blocks: elements)
    }
}
