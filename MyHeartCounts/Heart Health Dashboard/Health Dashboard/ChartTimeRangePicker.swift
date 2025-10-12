//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct ChartTimeRangePicker: View {
    @Binding var timeRange: DetailedHealthStatsView.ChartTimeRange
    
    var body: some View {
        Picker("", selection: $timeRange) {
            ForEach(DetailedHealthStatsView.ChartTimeRange.selectableOptions, id: \.self) { option in
                Text(option.displayTitle)
            }
        }
        .pickerStyle(.menu)
        .tint(.secondary)
    }
}
