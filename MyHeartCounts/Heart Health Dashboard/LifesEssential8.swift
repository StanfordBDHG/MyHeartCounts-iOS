//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


struct LifesEssential8: View {
    var body: some View {
        HealthDashboard(layout: [
            //.largeChart(sectionTitle: <#T##String?#>, component: <#T##HealthDashboardLayout.LargeChartComponent#>) // TODO!
            .grid(sectionTitle: "", components: [
                // NOTE: the grid components are laid out row-by-row, so if we want to have the 8 factors split up into 2 columns, we need to interleave them (as done below)
                // diet
                .init(.dietaryIron, chartConfig: .automatic),
                // weight
                .init(.bodyMass, chartConfig: .none),
                // physical activity
                .init(.physicalEffort, chartConfig: .automatic), // TODO which metric to use here? activeEnergy? physicalEffort?
                // blood lipids
                .init(.heartRate, chartConfig: .automatic), // TODO HealthKit doesn't seem to support blood lipids? how do we deal w/ that?
                // nicotine exposure
                .init(.rowingSpeed, chartConfig: .none),
                // blood glucose
                .init(.bloodGlucose, chartConfig: .none),
                // sleep
                .sleepAnalysis(),
                // blood pressure
                .bloodPressure()
            ])
        ])
    }
}
