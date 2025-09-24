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
    @State private var isECGSheetPresented = false
    
    var body: some View {
        NavigationStack {
            Form {
                TasksList(
                    mode: .upcoming(includeIndefinitePastTasks: false, showFallbackTasks: true),
                    timeRange: .weeks(2),
                    eventGroupingConfig: .byDay,
                    noTasksMessageLabels: .init(title: "No Upcoming Tasks")
                )
            }
            .navigationTitle(String(localized: Self.tabTitle))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    initiateActiveTaskMenu 
                }
                accountToolbarItem
            }
            .sheet(item: $activeTimedWalkingTest, id: \.self) { test in
                TimedWalkingTestView(test)
            }
            .sheet(isPresented: $isECGSheetPresented) {
                NavigationStack {
                    ECGInstructionsSheet(shouldOfferManualCompletion: false, successHandler: {})
                }
            }
        }
    }
    
    
    @ViewBuilder private var initiateActiveTaskMenu: some View {
        let timedWalkTests = [
            TimedWalkingTestConfiguration(duration: .minutes(6), kind: .walking),
            TimedWalkingTestConfiguration(duration: .minutes(12), kind: .running)
        ]
        Menu {
            ForEach(timedWalkTests, id: \.self) { test in
                Button {
                    activeTimedWalkingTest = test
                } label: {
                    Label(String(localized: test.displayTitle), systemSymbol: test.kind.symbol)
                }
            }
            Divider()
            Button {
                isECGSheetPresented = true
            } label: {
                Label("Take ECG", systemSymbol: .waveformPathEcgRectangle)
            }
        } label: {
            Label("Perform Active Task", systemSymbol: .plus)
        }
    }
}


extension UpcomingTasksTab {
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
