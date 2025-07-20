//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import Spezi
import SpeziAccount
import SpeziHealthKitBulkExport
import SpeziQuestionnaire
import SpeziScheduler
import SpeziSchedulerUI
import SpeziStudy
import SpeziStudyDefinition
import SpeziViews
import SwiftUI
import class ModelsR4.Questionnaire


/// The View for the "Home" tab in the root tab view.
struct HomeTab: RootViewTab {
    static var tabTitle: LocalizedStringResource { "My Heart Counts" }
    static var tabSymbol: SFSymbol { .cubeTransparent }
    
    @Environment(HistoricalHealthSamplesExportManager.self)
    private var historicalDataExportMgr
    
    @Environment(Account.self)
    private var account
    
    @State private var actionCards: [ActionCard] = []
    @State private var showSensorKitSheet = false
    
    @MissedEventQuery(in: TasksList.effectiveTimeRange(for: .weeks(2), cal: .current))
    private var missedEvents
    
    var body: some View {
        NavigationStack {
            Form {
                topActionsFormContent
                historicalHealthDataUploadSection
                TasksList(timeRange: .today, headerConfig: .custom("Today's Tasks"))
                missedEventsSection
            }
            .navigationTitle(String(localized: Self.tabTitle))
            .toolbar {
                accountToolbarItem
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSensorKitSheet = true
                    } label: {
                        Image(systemSymbol: .waveformPathEcgRectangle)
                    }
                }
            }
            .sheet(isPresented: $showSensorKitSheet) {
                NavigationStack {
                    SensorKitPlayground()
                }
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
    }
        
    @ViewBuilder private var historicalHealthDataUploadSection: some View {
        switch (historicalDataExportMgr.exportProgress, historicalDataExportMgr.fileUploader.uploadProgress) {
        case (nil, nil):
            EmptyView()
        case (.some(let exportProgress), nil):
            Section("Historical Data Bulk Export") {
                ProgressView(exportProgress)
            }
        case (nil, .some(let uploadProgress)):
            Section("Historical Data Bulk Export") {
                ProgressView(uploadProgress)
            }
        case let (.some(exportProgress), .some(uploadProgress)):
            Section("Historical Data Bulk Export") {
                ProgressView(exportProgress)
                ProgressView(uploadProgress)
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
                            headerConfig: .custom("Missed Tasks", subtitle: "Past 2 Weeks")
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
    
    @ViewBuilder
    private func sectionContent(for session: any BulkExportSession) -> some View {
        LabeledContent("State") {
            Text(session.state.displayTitle)
        }
        if let progress = session.progress {
            ProgressView(progress)
        }
    }
    
    private func eventButtonTitle(for category: Task.Category?) -> LocalizedStringResource? {
        switch category {
        case .informational:
            "Read Article"
        case .questionnaire:
            "Complete Questionnaire"
        default:
            nil
        }
    }
}


extension EventActionButton {
    init(event: Event, label: LocalizedStringResource?, action: @escaping () -> Void) {
        if let label {
            self.init(event: event, label, action: action)
        } else {
            self.init(event: event, action: action)
        }
    }
}


extension View {
    func styleAsMHCSectionHeader() -> some View {
        self
            .foregroundStyle(.secondary)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .font(.title2)
            .fontDesign(.rounded)
            .fontWeight(.bold)
    }
}
