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
import SpeziQuestionnaire
import SpeziScheduler
import SpeziSchedulerUI
import SpeziStudy
import SpeziStudyDefinition
import SpeziViews
import SwiftUI
import class ModelsR4.Questionnaire


/// The View for the "Home" tab in the root tab view.
struct HomeTabView: RootViewTab {
    private struct QuestionnaireBeingAnswered: Identifiable {
        let questionnaire: Questionnaire
        let SPC: StudyParticipationContext
        let event: Event
        var id: Questionnaire.ID { questionnaire.id }
    }
    
    static var tabTitle: LocalizedStringResource { "My Heart Counts" }
    static var tabSymbol: SFSymbol { .cubeTransparent }
    
    @Environment(MyHeartCountsStandard.self)
    private var standard
    
    @Environment(StudyManager.self)
    private var studyManager
    
    @EventQuery(in: Calendar.current.rangeOfMonth(for: .now))
    private var events
    
    @State private var presentedInformationalStudyComponent: StudyDefinition.InformationalComponent?
    @State private var questionnaireBeingAnswered: QuestionnaireBeingAnswered?
    @State private var viewState: ViewState = .idle
    
    @State private var actionCards: [ActionCard] = []
    
    @State private var isShowingHealthBulkUploadSheet = false
    
    var body: some View {
        NavigationStack { // swiftlint:disable:this closure_body_length
            Form {
                topActionsFormContent
                scheduleFormContent
            }
            .navigationTitle("My Heart Counts")
            .toolbar {
                accountToolbarItem
            }
            .viewStateAlert(state: $viewState)
            .sheet(item: $questionnaireBeingAnswered) { input in
                QuestionnaireView(
                    questionnaire: input.questionnaire,
                    completionStepMessage: "COMPLETION_STEP_MESSAGE",
                    cancelBehavior: .cancel
                ) { result in
                    questionnaireBeingAnswered = nil
                    switch result {
                    case .completed(let response):
                        do {
                            try input.event.complete()
                            try await standard.add(response: response)
                        } catch {
                            viewState = .error(error)
                        }
                    case .cancelled, .failed:
                        break
                    }
                }
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("HK Bulk Upload") {
                            isShowingHealthBulkUploadSheet = true
                        }
                    } label: {
                        Image(systemSymbol: .ladybug)
                            .tint(.red)
                            .accessibilityLabel("Debug Menu")
                    }
                }
            }
            #endif
            .sheet(isPresented: $isShowingHealthBulkUploadSheet) {
                NavigationStack {
                    TmpHealthKitBulkImportView()
                }
            }
        }
    }
    
    
    @ViewBuilder private var topActionsFormContent: some View {
        ForEach(actionCards) { card in
            Section {
                ActionCardView(card: card) { action in
                    await handleAction(action, for: nil)
                }
            }
        }
    }
    
    
    @ViewBuilder private var scheduleFormContent: some View {
        makeSection("Today's Tasks") { }
        if !events.isEmpty {
            ForEach(events) { event in
                Section {
                    if let action = event.task.studyScheduledTaskAction {
                        InstructionsTile(event) {
                            // IDEA(@lukas):
                            // - add an official overload with an optional label text?
                            // - make the button use an AsyncButton (or have a dedicated init overload that takes a ViewState and makes the button async)
                            EventActionButton(event: event, label: eventButtonTitle(for: event.task.category)) {
                                _Concurrency.Task {
                                    await handleAction(.scheduledTaskAction(action), for: event)
                                }
                            }
                        }
                    } else {
                        InstructionsTile(event)
                    }
                }
            }
            .injectingCustomTaskCategoryAppearances()
        } else {
            ContentUnavailableView(
                "No Tasks Scheduled for Today",
                systemSymbol: .partyPopper,
                description: Text("All of today's tasks have been completed")
            )
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
        }
    }
    
    
    private func handleAction(_ action: ActionCard.Action, for event: Event?) async {
        switch action {
        case .scheduledTaskAction(.presentInformationalStudyComponent(let component)):
            presentedInformationalStudyComponent = component
            // we consider simply presenting the component as being sufficient to complete the event.
            // NOTE ISSUE HERE: completing the event puts it into a state where you can't trigger it again (understandably...)
            // BUT: in this case, we do wanna allow this to happen again! how should we go about this?
            if let event {
                do {
                    try event.complete()
                } catch {
                    logger.error("Was unable to complete() event: \(error)")
                }
            }
        case let .scheduledTaskAction(.answerQuestionnaire(questionnaire, spcId)):
            guard let event else {
                return
            }
            guard let SPC = studyManager.SPC(withId: spcId) else {
                logger.error("Unable to find SPC")
                return
            }
            questionnaireBeingAnswered = .init(questionnaire: questionnaire, SPC: SPC, event: event)
        case .custom(let action):
            await action()
        }
//        switch action {
//        case .listAllAvailableStudies:
//            break
//        case .enrollInStudy(let study):
//            await enroll(in: study)
//        }
    }
    
    private func enroll(in study: StudyDefinition) async {
        do {
            try await _Concurrency.Task.sleep(for: .seconds(1))
            try await studyManager.enroll(in: study)
        } catch {
            viewState = .error(AnyLocalizedError(error: error))
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
