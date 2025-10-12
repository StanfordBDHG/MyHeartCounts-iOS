//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import SpeziHealthKit
import SpeziViews
import SwiftUI


extension HealthDashboardConstants {
    static let gridComponentCornerRadius: Double = 28
}


struct HealthDashboardSmallGridCell<Accessory: View, Content: View>: View {
    private static var insets: EdgeInsets { EdgeInsets(horizontal: 9, vertical: 5) }
    
    @Environment(\.isRecentValuesViewInDetailedStatsSheet)
    private var isRecentValuesViewInDetailedStatsSheet
    
    private let title: Text
    private let subtitle: Text?
    private let headerInsert: EdgeInsets
    private let accessory: Accessory
    private let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading) {
                        title
                            .font(.headline)
                        if let subtitle {
                            subtitle
                                .font(.subheadline)
                        }
                    }
                    Spacer()
                    accessory
                }
                .padding(headerInsert)
                .padding(EdgeInsets(top: Self.insets.top, leading: 0, bottom: Self.insets.top, trailing: 0))
                .frame(height: 57)
                Divider()
            }
            Spacer()
            content
            Spacer()
        }
        .if(!isRecentValuesViewInDetailedStatsSheet) {
            $0
                .padding(EdgeInsets(top: 0, leading: Self.insets.leading, bottom: Self.insets.bottom, trailing: Self.insets.trailing))
                .background(.background)
        }
        .frame(minHeight: 129)
    }
    
    init(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        headerInsert: EdgeInsets = .zero,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = Text(title)
        self.headerInsert = headerInsert
        self.subtitle = subtitle.map(Text.init)
        self.accessory = accessory()
        self.content = content()
    }
    
    @_disfavoredOverload
    init(
        title: some StringProtocol,
        subtitle: (some StringProtocol & SendableMetatype)? = String?.none,
        headerInsert: EdgeInsets = .zero,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = Text(title)
        self.headerInsert = headerInsert
        self.subtitle = subtitle.map(Text.init)
        self.accessory = accessory()
        self.content = content()
    }
}


struct HealthDashboardQuantityLabel: View {
    @Environment(\.calendar)
    private var cal
    
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
            // NOTE: displaying the entire range here technically won't always be correct (it's not incorrect either, just not perfect):
            // if we have a single-value grid cell that displays the max heart rate measured today, we'd have the label at the bottom say
            // "Today", even though displaying the precise time of this max heart rate measurement would be more correct.
            Text(input.timeRange.displayText(using: cal))
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }
}


extension HealthDashboardQuantityLabel {
    struct Input {
        let value: Double?
        let valueString: String
        let unitString: String
        let timeRange: Range<Date>
        
        init(value: Double?, valueString: String, unit: HKUnit, timeRange: Range<Date>) {
            func unitString(for unit: HKUnit) -> String {
                if unit == .count() {
                    ""
                } else {
                    unit.unitString
                }
            }
            self.value = value
            self.valueString = valueString
            self.unitString = unitString(for: unit)
            self.timeRange = timeRange
        }
        
        init(value: Double, sampleType: MHCQuantitySampleType, timeRange: Range<Date>) {
            let valueString = switch sampleType {
            case .healthKit(.bloodOxygen):
                String(format: "%.1f", value / 100)
            case .healthKit(.walkingAsymmetryPercentage), .healthKit(.walkingDoubleSupportPercentage):
                String(format: "%.2f", value / 100)
            case .healthKit(.bodyMassIndex):
                String(format: "%.1f", value)
            case _ where sampleType.displayUnit == .count():
                String(Int(value))
            default:
                if value.isWholeNumber {
                    String(Int(value))
                } else {
                    String(format: "%.2f", value)
                }
            }
            self.init(
                value: value,
                valueString: valueString,
                unit: sampleType.displayUnit,
                timeRange: timeRange
            )
        }
    }
}
