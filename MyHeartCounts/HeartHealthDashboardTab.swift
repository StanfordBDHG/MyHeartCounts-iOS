//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziViews
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI
import SFSafeSymbols


struct HeartHealthDashboardTab: RootViewTab {
    static var tabTitle: LocalizedStringKey {
        "Heart Health"
    }
    static var tabSymbol: SFSymbol {
        .heartTextSquare
    }
    
    @HealthKitQuery(.heartRate, timeRange: .today)
    private var heartRateSamples
    
    @HealthKitStatisticsQuery(.stepCount, aggregatedBy: [.sum], over: .day, timeRange: .last(weeks: 1))
    private var dailyStepCountStats
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HealthChart {
                        HealthChartEntry($heartRateSamples, drawingConfig: .init(mode: .line, color: .red))
                    }
                    .frame(height: 275)
                }
                Section {
                    HealthChart {
                        HealthChartEntry($dailyStepCountStats, aggregationOption: .sum, drawingConfig: .init(mode: .bar, color: .orange))
                    }
                    .frame(height: 275)
                }
            }
            .navigationTitle("Heart Health")
            .toolbar {
                accountToolbarItem
            }
        }
    }
}
