//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziAccount
import SwiftUI


/// The View for the "Home" tab in the root tab view.
struct HomeTab: RootViewTab {
    static var tabTitle: LocalizedStringResource { "My Heart Counts" }
    static var tabSymbol: SFSymbol { .cubeTransparent }
    
    @Environment(Account.self)
    private var account
    
    @MissedEventQuery(in: TasksList.effectiveTimeRange(for: .weeks(2), cal: .current))
    private var missedEvents
    
    @DailyNudge private var dailyNudge
    @State private var actionCards: [ActionCard] = []
    
    var body: some View {
        NavigationStack {
            Form {
                topActionsFormContent
                TasksList(
                    mode: .upcoming(includeIndefinitePastTasks: true, showFallbackTasks: false),
                    timeRange: .today,
                    headerConfig: .custom("Today's Tasks"),
                    eventGroupingConfig: .none,
                    noTasksMessageLabels: .init(title: "You're All Set")
                )
                missedEventsSection
            }
            .navigationTitle(String(localized: Self.tabTitle))
            .toolbar {
                accountToolbarItem
            }
        }
    }
    
    @ViewBuilder private var topActionsFormContent: some View {
        ForEach(actionCards) { card in
            Section {
                ActionCardView(card: card) { action in
                    switch action {
                    case .custom(let action):
                        await action()
                    }
                }
            }
        }
        if let dailyNudge {
            Section {
                VStack(alignment: .leading) {
                    Text(dailyNudge.title)
                        .font(.headline)
                    Text(dailyNudge.message)
                        .font(.subheadline)
                }
            }
        }
    }
    
    @ViewBuilder private var missedEventsSection: some View {
        if !missedEvents.isEmpty {
            Section {
                NavigationLink {
                    Form {
                        TasksList(
                            mode: .missed,
                            timeRange: .weeks(2),
                            headerConfig: .custom("Missed Tasks", subtitle: "Past 2 Weeks"),
                            eventGroupingConfig: .byDay,
                            noTasksMessageLabels: .init(title: "No Missed Tasks")
                        )
                    }
                    .navigationTitle("Missed Tasks")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    let numMissedTasks = missedEvents.count
                    Label(symbol: .calendar) {
                        VStack(alignment: .leading) {
                            Text("Missed Tasks")
                                .fontWeight(.medium)
                            Text("\(numMissedTasks) missed tasks in the past 2 weeks")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
