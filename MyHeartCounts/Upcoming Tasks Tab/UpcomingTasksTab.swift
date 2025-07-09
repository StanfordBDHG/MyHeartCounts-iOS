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
import SpeziStudyDefinition
import SwiftUI


struct UpcomingTasksTab: RootViewTab {
    static var tabTitle: LocalizedStringResource { "Upcoming Tasks" }
    static var tabSymbol: SFSymbol { .calendar }
    
    @Environment(\.calendar)
    private var calendar
    
    @State private var activeTimedWalkingTest: TimedWalkingTestConfiguration?
    
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
                UpcomingTasksList(timeRange: .fortnight, calendar: calendar)
            }
            .navigationTitle("Upcoming Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    timedWalkingTestMenu
                }
                accountToolbarItem
            }
            .sheet(item: $activeTimedWalkingTest, id: \.self) { test in
                TimedWalkingTestView(test)
            }
        }
    }
    
    @ViewBuilder private var timedWalkingTestMenu: some View {
        let tests = [
            TimedWalkingTestConfiguration(duration: .minutes(6), kind: .walking),
            TimedWalkingTestConfiguration(duration: .minutes(12), kind: .running)
        ]
        Menu {
            ForEach(tests, id: \.self) { test in
                Button {
                    activeTimedWalkingTest = test
                } label: {
                    Label(String(localized: test.displayTitle), systemSymbol: test.kind.symbol)
                }
            }
        } label: {
            Label("Timed Walking Test", systemSymbol: .figureWalk)
        }
    }
}
