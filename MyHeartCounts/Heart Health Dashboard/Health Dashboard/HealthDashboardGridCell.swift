//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit
import SwiftUI


extension HealthDashboard {
    struct SmallGridCell<Accessory: View, Content: View>: View {
        private static var insets: EdgeInsets { EdgeInsets(horizontal: 9, vertical: 5) }
        
        private let title: String
        private let accessory: @MainActor () -> Accessory
        private let content: @MainActor () -> Content
        
        var body: some View {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        if Accessory.self != EmptyView.self {
                            Spacer()
                            accessory()
                        }
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
            title: String, // TODO localized overload!
            @ViewBuilder accessory: @MainActor @escaping () -> Accessory = { EmptyView() },
            @ViewBuilder content: @MainActor @escaping () -> Content
        ) {
            self.title = title
            self.accessory = accessory
            self.content = content
        }
    }
}


extension HealthDashboard {
    struct QuantityLabel: View {
        struct Input {
            let valueString: String
            let unitString: String
            let timeRange: Range<Date>
            
            init(valueString: String, unitString: String, timeRange: Range<Date>) {
                self.valueString = valueString
                self.unitString = unitString
                self.timeRange = timeRange
            }
            
            init(value: Double, sampleType: MHCQuantitySampleType, timeRange: Range<Date>) {
                self.valueString = switch sampleType {
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
                self.unitString = sampleType.displayUnit.unitString
                self.timeRange = timeRange
            }
        }
        
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
                sampleDateText
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        
        // TODO if this is an aggregate sample stretching over a large time period, we want to show all of that?
        // eg: imagine a label displaying "total # exercise miniutes today / this week". that should probably just say "today" or "current week"
        private var sampleDateText: Text {
            if input.timeRange == cal.rangeOfDay(for: .now) {
                Text("Today")
            } else if input.timeRange.isEmpty, case let date = input.timeRange.lowerBound { // startDate == endDate
                if cal.isDateInToday(date) && date <= .now {
                    Text(date.formatted(date: .omitted, time: .shortened))
                } else {
                    // is older than today
                    Text(date.formatted(date: .numeric, time: .shortened))
                }
            } else {
                Text("TODO") // TODO
            }
        }
    }
}
