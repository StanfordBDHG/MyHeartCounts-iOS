//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit


struct HealthDashboardLayout: Hashable, Sendable {
    typealias ChartConfig = QuantityHealthStatGridCell.ChartConfig
    
    enum ComponentSize {
        case large
        case small
    }
    
    struct Block: Hashable, Sendable {
        enum Content: Hashable, Sendable {
            case large(LargeChartComponent)
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
            .init(title: sectionTitle, content: .large(component))
        }
        
        static func grid(sectionTitle: String, components: [GridComponent]) -> Self {
            .init(title: sectionTitle, content: .grid(components))
        }
    }
    
    
    struct LargeChartComponent: Hashable, Sendable {
        let sampleType: SampleTypeProxy
        let timeRange: HealthKitQueryTimeRange
        let chartConfig: ChartConfig
        
        private init(sampleType: SampleTypeProxy, timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig) {
            self.sampleType = sampleType
            self.timeRange = timeRange
            self.chartConfig = chartConfig
        }
        
        init(sampleType: SampleType<HKQuantitySample>, timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig) {
            self.init(sampleType: SampleTypeProxy(sampleType), timeRange: timeRange, chartConfig: chartConfig)
        }
        
        static func bloodPressure(timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig) -> Self {
            self.init(sampleType: SampleTypeProxy(.bloodPressure), timeRange: timeRange, chartConfig: chartConfig)
        }
    }
    
    
    /// A Health Stat Component within a Grid Section
    struct GridComponent: Hashable, Sendable {
        let sampleType: SampleTypeProxy
        let timeRange: HealthKitQueryTimeRange
        let chartConfig: ChartConfig?
        
        private init(sampleType: SampleTypeProxy, timeRange: HealthKitQueryTimeRange, chartConfig: ChartConfig?) {
            self.sampleType = sampleType
            self.timeRange = timeRange
            self.chartConfig = chartConfig
        }
        
        /// Creates a new Component
        /// - parameter sampleType: The `SampleType` the component should visualise.
        /// - parameter timeRange: The time range for which the component should visualise data.
        /// - parameter chartConfig: Whether the component should use a chart to visualize its data, and what the chart should look like.
        init(
            _ sampleType: SampleType<HKQuantitySample>,
            timeRange: HealthKitQueryTimeRange = .today, // swiftlint:disable:this function_default_parameter_at_end
            chartConfig: ChartConfig?
        ) {
            self.sampleType = .init(sampleType)
            self.timeRange = timeRange
            self.chartConfig = chartConfig
        }
        
        static func bloodPressure() -> Self {
            Self(sampleType: .init(.bloodPressure), timeRange: .last(days: 2), chartConfig: nil)
        }
        
        static func sleepAnalysis() -> Self {
            Self(sampleType: .init(.sleepAnalysis), timeRange: .last(days: 7), chartConfig: nil)
        }
    }
    
    
    var blocks: [Block]
    
    init(blocks: some Collection<Block> = []) {
        self.blocks = Array(blocks)
    }
}


extension HealthDashboardLayout: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Block...) {
        self.init(blocks: elements)
    }
}
