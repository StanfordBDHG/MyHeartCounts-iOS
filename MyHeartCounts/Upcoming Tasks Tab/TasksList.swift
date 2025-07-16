//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import Foundation
import SpeziQuestionnaire
import SpeziScheduler
import SpeziSchedulerUI
import SpeziStudy
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct TasksList: View {
    enum TimeRange {
        /// The time range starting today, and going `numDays` days into the future.
        case days(_ numDays: Int)
        /// The time range starting today, and going `numWeeks` weeks into the future.
        case weeks(_ numWeeks: Int)
        /// The time range starting today, and going `numMonths` months into the future.
        case months(_ numMonths: Int)
        
        /// The time range encompassing all of today.
        static let today = Self.days(1)
        
        /// The time range starting today, and going a week into the future.
        static let nextWeek = Self.weeks(1)
        /// The time range starting today, and going 14 days into the future.
        static let fortnight = Self.weeks(2)
        /// The time range starting today, and going a month into the future.
        static let month = Self.months(1)
    }
    
    enum Mode {
        /// The ``TasksList`` should display a list of upcoming Tasks
        case upcoming
        /// The ``TasksList`` should display a list of missed but not yet expired Tasks
        case missed
    }
    
    enum HeaderConfig {
        case none
        case custom(String, subtitle: String = "")
        case timeRange
    }
    
    private struct QuestionnaireBeingAnswered: Identifiable {
        let questionnaire: Questionnaire
        let enrollment: StudyEnrollment
        let event: Event
        var id: Questionnaire.ID { questionnaire.id }
    }
    
    
    @Environment(\.calendar)
    private var cal
    @Environment(MyHeartCountsStandard.self)
    private var standard
    @Environment(StudyManager.self)
    private var studyManager
    
    private let mode: Mode
    private let timeRange: TimeRange
    private let headerConfig: HeaderConfig
    
    @State private var viewState: ViewState = .idle
    @State private var presentedArticle: Article?
    @State private var questionnaireBeingAnswered: QuestionnaireBeingAnswered?
    @State private var presentedTimedWalkingTest: StudyDefinition.TimedWalkingTestComponent?
    
    var body: some View {
        header
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
        let effectiveTimeRange = Self.effectiveTimeRange(for: timeRange, cal: cal)
        switch mode {
        case .upcoming:
            UpcomingEventsQuery(effectiveTimeRange) { events in
                Impl(events: events) {
                    await handleAction($0, for: $1, context: $2)
                }
            }
        case .missed:
            MissedEventsQuery(effectiveTimeRange) { events in
                Impl(events: events) {
                    await handleAction($0, for: $1, context: $2)
                }
            }
        }
    }
    
    @ViewBuilder private var header: some View {
        let (title, subtitle) = headerContents
        VStack(alignment: .leading) {
            Text(title)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .fontDesign(.rounded)
            }
        }
        .styleAsMHCSectionHeader()
    }
    
    private var headerContents: (String, String) {
        switch headerConfig {
        case .none:
            return ("", "")
        case let .custom(title, subtitle):
            return (title, subtitle)
        case .timeRange:
            let (title, needsSubtitle) = switch timeRange {
            case .days(1):
                ("Today", false)
            case .days(let numDays):
                ("Next \(numDays) Days", true)
            case .weeks(1):
                ("Next Week", true)
            case .weeks(let numWeeks):
                ("Next \(numWeeks) Weeks", true)
            case .months(1):
                ("Next Month", true)
            case .months(let numMonths):
                ("Next \(numMonths) Months", true)
            }
            if needsSubtitle {
                let timeRange = Self.effectiveTimeRange(for: timeRange, cal: cal)
                let start = timeRange.lowerBound.formatted(date: .numeric, time: .omitted)
                let end = timeRange.upperBound.addingTimeInterval(-1).formatted(date: .numeric, time: .omitted)
                return (title, "\(start) – \(end)")
            } else {
                return (title, "")
            }
        }
    }
    
    init(
        mode: Mode = .upcoming, // swiftlint:disable:this function_default_parameter_at_end
        timeRange: TimeRange,
        headerConfig: HeaderConfig = .timeRange
    ) {
        self.mode = mode
        self.timeRange = timeRange
        self.headerConfig = headerConfig
    }
    
    private func handleAction(_ action: StudyManager.ScheduledTaskAction, for event: Event, context: Task.Context.StudyContext) async {
        switch action {
        case .presentInformationalStudyComponent(let component):
            guard let enrollment = studyManager.enrollment(withId: context.enrollmentId),
                  let studyBundle = enrollment.studyBundle,
                  let article = Article(component, in: studyBundle, locale: studyManager.preferredLocale) else {
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
                  let questionnaire = studyBundle.questionnaire(for: component.fileRef, in: studyManager.preferredLocale) else {
                logger.error("Unable to find SPC")
                return
            }
            questionnaireBeingAnswered = .init(questionnaire: questionnaire, enrollment: enrollment, event: event)
        case .promptTimedWalkingTest(let component):
            presentedTimedWalkingTest = component
        }
    }
}


extension TasksList {
    static func effectiveTimeRange(for timeRange: TimeRange, cal: Calendar) -> Range<Date> {
        switch timeRange {
        case .days(let numDays):
            let start = cal.startOfDay(for: .now)
            let end = cal.date(byAdding: .day, value: numDays, to: start) ?? start
            return start..<end
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


extension TasksList {
    private struct UpcomingEventsQuery<Content: View>: View {
        @EventQuery private var events: [Event]
        private let content: @MainActor ([Event]) -> Content
        
        var body: some View {
            content(events)
        }
        
        init(_ timeRange: Range<Date>, @ViewBuilder content: @escaping @MainActor ([Event]) -> Content) {
            _events = .init(in: timeRange)
            self.content = content
        }
    }
    
    
    private struct MissedEventsQuery<Content: View>: View {
        @MissedEventQuery private var events: [Event]
        private let content: @MainActor ([Event]) -> Content
        
        var body: some View {
            content(events)
        }
        
        init(_ timeRange: Range<Date>, @ViewBuilder content: @escaping @MainActor ([Event]) -> Content) {
            _events = .init(in: timeRange)
            self.content = content
        }
    }
    
    
    private struct Impl: View {
        typealias SelectionHandler = @MainActor (
            _ action: StudyManager.ScheduledTaskAction,
            _ event: Event,
            _ context: Task.Context.StudyContext
        ) async -> Void
        
        private struct SectionedEvents {
            let startOfDay: Date
            let events: [Event]
        }
        
        @Environment(\.calendar)
        private var cal
        private let events: [Event]
        private let selectionHandler: SelectionHandler
        
        var body: some View {
            if !events.isEmpty {
                let eventsByDay = eventsByDay
                ForEach(eventsByDay, id: \.startOfDay) { sectionedEvents in
                    Section {
                        ForEach(sectionedEvents.events) { event in
                            if let context = event.task.studyContext,
                               let action = event.task.studyScheduledTaskAction {
                                InstructionsTile(event) {
                                    // IDEA(@lukas):
                                    // - add an official overload with an optional label text?
                                    // - make the button use an AsyncButton (or have a dedicated init overload that takes a ViewState and makes the button async)
                                    EventActionButton(event: event, label: eventButtonTitle(for: event.task.category)) {
                                        _Concurrency.Task {
                                            await selectionHandler(action, event, context)
                                        }
                                    }
                                }
                            } else {
                                InstructionsTile(event)
                            }
                        }
                    } header: {
                        if eventsByDay.count > 1 {
                            Text(sectionedEvents.startOfDay.formatted(date: .long, time: .omitted))
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
        
        private var eventsByDay: [SectionedEvents] {
            events.chunked { cal.isDate($0.occurrence.start, inSameDayAs: $1.occurrence.start) }
                // SAFETY: the chunking guarantees that the slices aren't empty.
                // we need to use `.first` instead of `[0]`, since the slices share the indices.
                // swiftlint:disable:next force_unwrapping
                .map { SectionedEvents(startOfDay: cal.startOfDay(for: $0.first!.occurrence.start), events: Array($0)) }
        }
        
        init(events: [Event], selectionHandler: @escaping SelectionHandler) {
            self.events = events
            self.selectionHandler = selectionHandler
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
}
