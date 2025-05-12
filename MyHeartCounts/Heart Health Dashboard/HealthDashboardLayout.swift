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
    enum ComponentSize {
        case large
        case small
    }
    
    struct Block: Hashable, Sendable {
        enum Content: Hashable, Sendable {
            case large(SampleType<HKQuantitySample>, QuantityHealthStatGridCell.ChartConfig?)
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
            sampleType: SampleType<HKQuantitySample>,
            chartConfig: QuantityHealthStatGridCell.ChartConfig? = nil
        ) -> Self {
            .init(title: sectionTitle, content: .large(sampleType, chartConfig))
        }
        
        static func grid(sectionTitle: String, components: [GridComponent]) -> Self {
            .init(title: sectionTitle, content: .grid(components))
        }
    }
    
    struct GridComponent: Hashable, Sendable {
        let sampleType: SampleTypeProxy
        let chartConfig: QuantityHealthStatGridCell.ChartConfig?
        
        init(sampleType: SampleType<HKQuantitySample>, chartConfig: QuantityHealthStatGridCell.ChartConfig?) {
            self.sampleType = .init(sampleType)
            self.chartConfig = chartConfig
        }
        
        init(sampleType: any AnySampleType) {
            self.sampleType = .init(sampleType)
            self.chartConfig = nil
        }
    }
    
    
    let blocks: [Block]
}


extension HealthDashboardLayout: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Block...) {
        self.init(blocks: elements)
    }
}
