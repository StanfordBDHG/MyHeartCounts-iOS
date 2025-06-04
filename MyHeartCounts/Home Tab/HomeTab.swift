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
    static var tabTitle: LocalizedStringResource { "MyHeart Counts" }
    static var tabSymbol: SFSymbol { .cubeTransparent }
    
    @Environment(HistoricalHealthSamplesExportManager.self)
    private var historicalDataExportMgr
    
    @Environment(\.calendar)
    private var calendar
    
    @LocalPreference(.enableDebugMode)
    private var enableDebugMode
    
    @State private var actionCards: [ActionCard] = []
    
    var body: some View {
        NavigationStack {
            Form {
                topActionsFormContent
                historicalHealthDataUploadSection
                scheduleFormContent
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
    }
    
    @ViewBuilder private var scheduleFormContent: some View {
        makeSection("Today's Tasks") {
            UpcomingTasksList(timeRange: .today, calendar: calendar)
        }
    }
        
    @ViewBuilder private var historicalHealthDataUploadSection: some View {
        switch (historicalDataExportMgr.exportProgress, historicalDataExportMgr.uploadProgress) {
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
    
    private func makeSection(_ title: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
        Section {
            content()
        } header: {
            Text(title)
                .foregroundStyle(.secondary)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .font(.title2)
                .fontDesign(.rounded)
                .fontWeight(.bold)
                .padding(.bottom, 12)
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
