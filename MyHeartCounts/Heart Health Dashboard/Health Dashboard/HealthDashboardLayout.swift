//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all - parts of the API simply are unused, but we want to keep them around for the future.

import Foundation
import MyHeartCountsShared
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


struct HealthDashboardLayout: Sendable {
    var blocks: [Block]
    
    init(blocks: some Collection<Block> = []) {
        self.blocks = Array(blocks)
    }
    
    init(@ArrayBuilder<Block> blocks: () -> [Block]) {
        self.init(blocks: blocks())
    }
}


extension HealthDashboardLayout {
    struct Block: Sendable {
        enum Content: Sendable {
            case largeCustom(@MainActor () -> AnyView)
            case grid([GridComponent])
        }
        
        let title: LocalizedStringResource?
        let footer: LocalizedStringResource?
        let content: Content
        
        private init(title: LocalizedStringResource?, footer: LocalizedStringResource?, content: Content) {
            self.title = title
            self.footer = footer
            self.content = content
        }
        
        static func large(
            sectionTitle: LocalizedStringResource? = nil,
            footer: LocalizedStringResource? = nil,
            @ViewBuilder content: @MainActor @escaping () -> some View
        ) -> Self {
            .init(title: sectionTitle, footer: footer, content: .largeCustom {
                content().intoAnyView()
            })
        }
        
        static func grid(
            sectionTitle: LocalizedStringResource? = nil,
            footer: LocalizedStringResource? = nil,
            components: [GridComponent]
        ) -> Self {
            .init(title: sectionTitle, footer: footer, content: .grid(components))
        }
        
        static func grid(
            sectionTitle: LocalizedStringResource? = nil,
            footer: LocalizedStringResource? = nil,
            @ArrayBuilder<GridComponent> components: () -> [GridComponent]
        ) -> Self {
            .init(title: sectionTitle, footer: footer, content: .grid(components()))
        }
    }
}


// MARK: Styles and related Configs

extension HealthDashboardLayout {
    struct ChartConfig: Sendable {
        let chartType: ChartDataSetDrawingConfig.ChartType
        let aggregationInterval: HealthKitStatisticsQuery.AggregationInterval
        
        init(chartType: ChartDataSetDrawingConfig.ChartType, aggregationInterval: HealthKitStatisticsQuery.AggregationInterval) {
            self.chartType = chartType
            self.aggregationInterval = aggregationInterval
        }
        
        init(chartType: ChartDataSetDrawingConfig.ChartType, defaultAggregationIntervalFor timeRange: HealthKitQueryTimeRange) {
            self.init(chartType: chartType, aggregationInterval: Self.defaultSmallChartAggregationInterval(for: timeRange))
        }
        
        static func `default`(for sampleType: SampleType<HKQuantitySample>, in timeRange: HealthKitQueryTimeRange) -> Self {
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
        
        private static func defaultSmallChartAggregationInterval(
            for timeRange: HealthKitQueryTimeRange
        ) -> HealthKitStatisticsQuery.AggregationInterval {
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
    
    
    enum DataSource: Sendable {
        case healthKit(SampleTypeProxy)
        case firebase(CustomQuantitySampleType)
    }
    
    /// A Component within a Grid Section
    struct GridComponent: Sendable {
        let title: String
        let accessibilityIdentifier: String
        let headerInsets: EdgeInsets
        let content: @MainActor () -> AnyView
        let tapAction: (@MainActor () -> Void)?
        
        init(
            title: String,
            accessibilityIdentifier: String?,
            headerInsets: EdgeInsets = .zero,
            @ViewBuilder _ content: @MainActor @escaping () -> some View,
            onTap tapAction: (@MainActor () -> Void)? = nil
        ) {
            self.title = title
            self.accessibilityIdentifier = accessibilityIdentifier ?? title
            self.headerInsets = headerInsets
            self.content = { content().intoAnyView() }
            self.tapAction = tapAction
        }
    }
}


extension HealthDashboardLayout: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Block...) {
        self.init(blocks: elements)
    }
}
