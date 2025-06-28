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
import SpeziStudyDefinition
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
    
    @Environment(\.locale)
    private var locale
    @Environment(MyHeartCountsStandard.self)
    private var standard
    @Environment(StudyManager.self)
    private var studyManager
    @EventQuery private var events: [Event]
    @State private var viewState: ViewState = .idle
    @State private var presentedArticle: Article?
    @State private var questionnaireBeingAnswered: QuestionnaireBeingAnswered?
    @State private var presentedTimedWalkingTest: StudyDefinition.TimedWalkingTestComponent?
    
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
            .sheet(item: $presentedArticle) { article in
                ArticleSheet(article: article)
            }
            .sheet(item: $presentedTimedWalkingTest) { component in
                NavigationStack {
                    TimedWalkingTestView(component.test)
                }
            }
    }
    
    @ViewBuilder private var eventsList: some View {
        if !events.isEmpty {
            ForEach(events) { event in
                Section {
                    if let context = event.task.studyContext,
                       let action = event.task.studyScheduledTaskAction {
                        InstructionsTile(event) {
                            // IDEA(@lukas):
                            // - add an official overload with an optional label text?
                            // - make the button use an AsyncButton (or have a dedicated init overload that takes a ViewState and makes the button async)
                            EventActionButton(event: event, label: eventButtonTitle(for: event.task.category)) {
                                _Concurrency.Task {
                                    await handleAction(action, for: event, context: context)
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
    
    init(timeRange: TimeRange, calendar: Calendar) {
        _events = .init(in: Self.effectiveTimeRange(for: timeRange, calendar: calendar))
    }
    
    private func handleAction(_ action: StudyManager.ScheduledTaskAction, for event: Event, context: Task.Context.StudyContext) async {
        switch action {
        case .presentInformationalStudyComponent(let component):
            guard let enrollment = studyManager.enrollment(withId: context.enrollmentId),
                  let studyBundle = enrollment.studyBundle,
                  let article = Article(component, in: studyBundle, locale: locale) else {
                logger.error("Error fetching&loading&procesing Article")
                return
            }
            presentedArticle = article
            // we consider simply presenting the component as being sufficient to complete the event.
            // NOTE ISSUE HERE: completing the event puts it into a state where you can't trigger it again (understandably...)
            // BUT: in this case, we do wanna allow this to happen again! how should we go about this?
            do {
                try event.complete()
            } catch {
                logger.error("Was unable to complete() event: \(error)")
            }
        case .answerQuestionnaire(let component):
            guard let enrollment = studyManager.enrollment(withId: context.enrollmentId),
                  let studyBundle = enrollment.studyBundle,
                  let questionnaire = studyBundle.questionnaire(for: component.fileRef, in: locale) else {
                logger.error("Unable to find SPC")
                return
            }
            questionnaireBeingAnswered = .init(questionnaire: questionnaire, enrollment: enrollment, event: event)
        case .promptTimedWalkingTest(let component):
            presentedTimedWalkingTest = component
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
    private static func effectiveTimeRange(for timeRange: TimeRange, calendar: Calendar) -> Range<Date> {
        switch timeRange {
        case .today:
            return calendar.rangeOfDay(for: .now)
        case .weeks(let numWeeks):
            let start = calendar.startOfDay(for: .now)
            let end = calendar.date(byAdding: .weekOfYear, value: numWeeks, to: start) ?? start
            return start..<end
        case .months(let numMonths):
            let start = calendar.startOfDay(for: .now)
            let end = calendar.date(byAdding: .month, value: numMonths, to: start) ?? start
            return start..<end
        }
    }
}
