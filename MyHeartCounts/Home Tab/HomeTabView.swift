//
//  HomeTabView.swift
//  MyHeartCounts
//
//  Created by Lukas Kollmer on 2025-03-02.
//

import Foundation
import SFSafeSymbols
import Spezi
import SpeziAccount
import SpeziQuestionnaire
@_spi(TestingSupport)
import SpeziScheduler
import SpeziSchedulerUI
import SpeziStudy
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
    
    // TODO we could also call it "Schedule", but depending on whether we want
    // eg the Health Charts in here or in a fully separate tab, this might not be the best idea?
    static var tabTitle: LocalizedStringKey { "Home" }
    static var tabSymbol: SFSymbol { .cubeTransparent }
    
    @Environment(\.modelContext) private var modelContext
    @Environment(MHC.self) private var mhc
//    @Environment(Account.self) private var account: Account?
    @Environment(Scheduler.self) private var scheduler
    
    @EventQuery(in: Calendar.current.rangeOfMonth(for: .now)) private var events
    
    //@State private var presentedEvent: Event?
    
    @State private var isStudyEnrollmentSheetPresented = false
    @State private var informationalStudyComponentBeingDisplayed: StudyDefinition.InformationalComponent?
    @State private var questionnaireBeingAnswered: QuestionnaireBeingAnswered?
    @State private var viewState: ViewState = .idle
    
    
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
            .sheet(isPresented: $isStudyEnrollmentSheetPresented) {
                StudyEnrollmentView { study in
                    fatalError()
                }
            }
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
                            let entry = SPCQuestionnaireEntry(SPC: input.SPC, response: response)
                            modelContext.insert(entry) // TODO QUESTION: does this cause the property in the SPC class to get updated???
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
//                        Button("Reload Root View") {
//                            reloadRootView()
//                        }
                        AsyncButton("Debug Scheduler Stuff", state: $viewState) {
                            try await debugSchedulerStuff()
                        }
                    } label: {
                        Image(systemSymbol: .ladybug)
                            .tint(.red)
                            .accessibilityLabel("Debug Menu")
                    }
                }
            }
            #endif
        }
    }
    
    
    @ViewBuilder private var topActionsFormContent: some View {
        ForEach(mhc.actionCards) { card in
            Section {
                ActionCardView(card: card) { action in
                    await handleAction(action, for: nil)
                }
            }
        }
    }
    
    
    @ViewBuilder private var scheduleFormContent: some View {
        makeSection("Today's Tasks") { } // swiftlint:disable:this closure_body_length
        if !events.isEmpty {
            ForEach(events) { event in
                Section {
                    if let action = event.task.studyScheduledTaskAction {
                        InstructionsTile(event) {
                            // TODO(@lukas):
                            // - add an official overload with an optional label text?
                            // - make the button use an AsyncButton (or have a dedicated init overload that takes a ViewState and makes the button async)
                            EventActionButton(event: event, label: eventButtonTitle(for: event.task.category)) {
                                _Concurrency.Task {
                                    await handleAction(action, for: event)
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
    
    
    private func handleAction(_ action: MHC.ActionCard.Action, for event: Event?) async {
        switch action {
        case .listAllAvailableStudies:
            isStudyEnrollmentSheetPresented = true
        case .enrollInStudy(let study):
            await enroll(in: study)
        case .presentInformationalStudyComponent(let component):
            informationalStudyComponentBeingDisplayed = component
            // we consider simply presenting the component as being sufficient to complete the event.
            // TODO ISSUE HERE: completing the event puts it into a state where you can't trigger it again (understandably...)
            // BUT: in this case, we do wanna allow this to happen again! how should we go about this?
            try? event?.complete()
        case .answerQuestionnaire(let questionnaire, let spcId):
            //path.append(questionnaire)
            let SPC: StudyParticipationContext = modelContext.registeredModel(for: spcId)!
            questionnaireBeingAnswered = .init(questionnaire: questionnaire, SPC: SPC, event: event!)
        }
    }
    
    private func enroll(in study: StudyDefinition) async {
        do {
            try await _Concurrency.Task.sleep(for: .seconds(1))
            try await mhc.enroll(in: study)
        } catch {
            viewState = .error(AnyLocalizedError(error: error))
        }
    }
    
    
    func debugSchedulerStuff() async throws {
        let outcomes = try scheduler.queryAllOutcomes()
        print("#outcomes: \(outcomes.count)")
        for outcome in outcomes {
            print(outcome)
        }
        fatalError()
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
