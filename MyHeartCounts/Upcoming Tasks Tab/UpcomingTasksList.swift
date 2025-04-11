//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziQuestionnaire
import SpeziScheduler
import SpeziSchedulerUI
import SpeziStudy
import SpeziViews
import SwiftUI


struct UpcomingTasksList: View {
    enum TimeRange {
        /// The time range encompassing all of today.
        case today
        /// The time range starting today, and going `numWeeks` weeks into the future.
        case weeks(_ numWeeks: Int)
        /// The time range starting today, and going `numMonths` months into the future.
        case months(_ numMonths: Int)
        
        /// The time range starting today, and going a week into the future.
        static let nextWeek = Self.weeks(1)
        /// The time range starting today, and going 14 days into the future.
        static let fortnight = Self.weeks(2)
        /// The time range starting today, and going a month into the future.
        static let month = Self.months(1)
    }
    
    private struct QuestionnaireBeingAnswered: Identifiable {
        let questionnaire: Questionnaire
        let enrollment: StudyEnrollment
        let event: Event
        var id: Questionnaire.ID { questionnaire.id }
    }
    
    @Environment(MyHeartCountsStandard.self)
    private var standard
    @Environment(StudyManager.self)
    private var studyManager
    @EventQuery private var events: [Event]
    @State private var viewState: ViewState = .idle
    @State private var presentedInformationalStudyComponent: StudyDefinition.InformationalComponent?
    @State private var questionnaireBeingAnswered: QuestionnaireBeingAnswered?
    
    var body: some View {
        eventsList
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
                            await standard.add(response: response)
                        } catch {
                            viewState = .error(error)
                        }
                    case .cancelled, .failed:
                        break
                    }
                }
            }
            .sheet(item: $presentedInformationalStudyComponent) { component in
                ArticleSheet(content: .init(component))
            }
    }
    
    @ViewBuilder private var eventsList: some View {
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
                "No Upcoming Tasks",
                systemSymbol: .partyPopper,
                description: Text("All tasks have already been completed!")
            )
        }
    }
    
    init(timeRange: TimeRange) {
        _events = .init(in: Self.effectiveTimeRange(for: timeRange))
    }
    
    private func handleAction(_ action: StudyManager.ScheduledTaskAction, for event: Event) async {
        switch action {
        case .presentInformationalStudyComponent(let component):
            presentedInformationalStudyComponent = component
            // we consider simply presenting the component as being sufficient to complete the event.
            // NOTE ISSUE HERE: completing the event puts it into a state where you can't trigger it again (understandably...)
            // BUT: in this case, we do wanna allow this to happen again! how should we go about this?
//            do {
//                try event.complete()
//            } catch {
//                logger.error("Was unable to complete() event: \(error)")
//            }
        case let .answerQuestionnaire(questionnaire, spcId):
            guard let enrollment = studyManager.enrollment(withId: spcId) else {
                logger.error("Unable to find SPC")
                return
            }
            questionnaireBeingAnswered = .init(questionnaire: questionnaire, enrollment: enrollment, event: event)
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


extension UpcomingTasksList {
    private static func effectiveTimeRange(for timeRange: TimeRange) -> Range<Date> {
        let cal = Calendar.current
        switch timeRange {
        case .today:
            return cal.rangeOfDay(for: .now)
        case .weeks(let numWeeks):
            let start = cal.startOfDay(for: .now)
            let end = cal.date(byAdding: .weekOfYear, value: numWeeks, to: start) ?? start
            return start..<end
        case .months(let numMonths):
            let start = cal.startOfDay(for: .now)
            let end = cal.date(byAdding: .month, value: numMonths, to: start) ?? start
            return start..<end
        }
    }
}
