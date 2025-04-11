//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import SpeziScheduler
import SpeziSchedulerUI
import SwiftUI


struct UpcomingTasksTab: RootViewTab {
    static var tabTitle: LocalizedStringResource { "Upcoming Tasks" }
    static var tabSymbol: SFSymbol { .calendar }
    
    
    var body: some View {
        NavigationStack {
            Form {
                Text("Next 2 weeks")
                    .foregroundStyle(.secondary)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .font(.title2)
                    .fontDesign(.rounded)
                    .fontWeight(.bold)
                // maybe lower the spacing inbetween these?
                UpcomingTasksList(timeRange: .fortnight)
            }
            .navigationTitle("Upcoming Tasks")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
