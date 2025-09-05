//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import SpeziFoundation
import SpeziScheduler
import SpeziSchedulerUI
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct UpcomingTasksTab: RootViewTab {
    static var tabTitle: LocalizedStringResource { "Upcoming Tasks" }
    static var tabSymbol: SFSymbol { .calendar }
    
    @State private var activeTimedWalkingTest: TimedWalkingTestConfiguration?
    
    var body: some View {
        NavigationStack {
            Form {
                TasksList(
                    mode: .upcoming(showFallbackTasks: true),
                    timeRange: .weeks(2),
                    noTasksMessageLabels: .init(title: "No Upcoming Tasks")
                )
            }
            .navigationTitle(String(localized: Self.tabTitle))
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
            Label("Timed Walk Test", systemSymbol: .figureWalk)
        }
    }
}


extension UpcomingTasksTab {
//    static func sectionHeader(
//        title: LocalizedStringResource,
//        subtitle: LocalizedStringResource?
//    ) -> some View {
//        sectionHeader(title: title.localizedString(), subtitle: subtitle?.localizedString() ?? "")
//    }
    
    static func sectionHeader(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil
    ) -> some View {
        Section {
            VStack(alignment: .leading) {
                Text(title)
                if let subtitle, !String(localized: subtitle).isEmpty {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .fontDesign(.rounded)
                }
            }
            .foregroundStyle(.secondary)
            .listRowInsets(.init(top: 0, leading: 8, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .font(.title2)
            .fontDesign(.rounded)
            .fontWeight(.bold)
        }
        .listSectionSpacing(.compact)
    }
}
