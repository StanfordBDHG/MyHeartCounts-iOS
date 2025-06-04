//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Charts
import Foundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


struct BloodPressureGridCell: View {
    @HealthKitQuery(.bloodPressure, timeRange: .last(months: 6))
    private var samples
    
    var body: some View {
        HealthDashboardSmallGridCell(title: $samples.sampleType.displayTitle) {
            if let sample = samples.last,
               let systolic = sample.firstSample(ofType: .bloodPressureSystolic),
               let diastolic = sample.firstSample(ofType: .bloodPressureDiastolic) {
                let unit = SampleType.bloodPressureSystolic.displayUnit
                HealthDashboardQuantityLabel(input: .init(
                    valueString: "\(Int(systolic.quantity.doubleValue(for: unit)))/\(Int(diastolic.quantity.doubleValue(for: unit)))",
                    unitString: unit.unitString,
                    timeRange: sample.timeRange
                ))
            }
        }
    }
}
