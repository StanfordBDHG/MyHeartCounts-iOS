//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_length attributes

import Algorithms
import Foundation
import OSLog
import ResearchKitSwiftUI
import SFSafeSymbols
import SpeziFoundation
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
        /// The list should display a list of upcoming Tasks
        case upcoming(includeIndefinitePastTasks: Bool, showFallbackTasks: Bool)
        /// The list should display a list of missed but not yet expired Tasks
        case missed
    }
    
    /// How the individual events in the list should be grouped.
    enum EventGroupingConfig {
        case none
        case byDay
    }
    
    enum HeaderConfig {
        case none
        case custom(LocalizedStringResource, subtitle: LocalizedStringResource? = nil)
        case timeRange
    }
    
    struct NoTasksMessageLabels {
        let title: LocalizedStringResource
        let subtitle: LocalizedStringResource
        
        init(
            title: LocalizedStringResource,
            subtitle: LocalizedStringResource = "All tasks have been completed!"
        ) {
            self.title = title
            self.subtitle = subtitle
        }
    }
    
    private struct QuestionnaireBeingAnswered: Identifiable {
        let questionnaire: Questionnaire
        let enrollment: StudyEnrollment
        let event: Event
        let shouldCompleteEvent: Bool
        var id: Questionnaire.ID { questionnaire.id }
    }
    
    private struct ActiveTimedWalkingTest: Identifiable {
        let test: TimedWalkingTestConfiguration
        let event: Event?
        let shouldCompleteEvent: Bool
        
        var id: AnyHashable {
            (event?.id).map { AnyHashable($0) } ?? AnyHashable(test)
        }
        
        init(test: TimedWalkingTestConfiguration, event: Event, shouldCompleteEvent: Bool) {
            self.test = test
            self.event = event
            self.shouldCompleteEvent = shouldCompleteEvent
        }
        
        init(test: TimedWalkingTestConfiguration) {
            self.test = test
            self.event = nil
            self.shouldCompleteEvent = false
        }
    }
    
    private struct ActiveECG: Identifiable {
        let id = UUID()
        let didComplete: @MainActor () -> Void
    }
    
    
    @Environment(\.calendar) private var cal
    @Environment(MyHeartCountsStandard.self) private var standard
    @Environment(StudyManager.self) private var studyManager
    
    private let mode: Mode
    private let timeRange: TimeRange
    private let headerConfig: HeaderConfig
    private let eventGroupingConfig: EventGroupingConfig
    private let noTasksMessageLabels: NoTasksMessageLabels
    
    @State private var viewState: ViewState = .idle
    @State private var presentedArticle: Article?
    @State private var questionnaireBeingAnswered: QuestionnaireBeingAnswered?
    @State private var activeTimedWalkingTest: ActiveTimedWalkingTest?
    @State private var activeECG: ActiveECG?
    
    var body: some View {
        header
            .viewStateAlert(state: $viewState)
            .sheet(item: $questionnaireBeingAnswered) { input in
                QuestionnaireView(
                    questionnaire: input.questionnaire,
                    cancelBehavior: .cancel
                ) { result in
                    questionnaireBeingAnswered = nil
                    switch result {
                    case .completed(let response):
                        do {
                            if input.shouldCompleteEvent {
                                try input.event.complete()
                            }
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
            .sheet(item: $activeTimedWalkingTest) { input in
                NavigationStack {
                    TimedWalkingTestView(input.test) { result in
                        if result != nil, let event = input.event, input.shouldCompleteEvent {
                            _ = try? event.complete()
                        }
                    }
                }
            }
            .sheet(item: $activeECG) { input in
                NavigationStack {
                    ECGInstructionsSheet(
                        shouldOfferManualCompletion: true,
                        successHandler: input.didComplete
                    )
                }
            }
        tasksList
            .injectingCustomTaskCategoryAppearances()
            .taskCategoryAppearance(for: .customActiveTask(.ecg), label: "Electrocardiogram", image: .system(.waveformPathEcgRectangle))
    }
    
    @ViewBuilder private var header: some View {
        let (title, subtitle) = headerContents
        UpcomingTasksTab.sectionHeader(
            title: title,
            subtitle: subtitle
        )
    }
    
    private var headerContents: (LocalizedStringResource, LocalizedStringResource?) {
        switch headerConfig {
        case .none:
            return ("", nil)
        case let .custom(title, subtitle):
            return (title, subtitle)
        case .timeRange:
            let (title, needsSubtitle): (LocalizedStringResource, Bool) = switch timeRange {
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
                return (title, nil)
            }
        }
    }
    
    @ViewBuilder private var tasksList: some View {
        let effectiveTimeRange = Self.effectiveTimeRange(for: timeRange, cal: cal)
        switch mode {
        case let .upcoming(includeIndefinitePastTasks, showFallbackTasks):
            if includeIndefinitePastTasks, let dateOfEnrollment = studyManager.studyEnrollments.first?.enrollmentDate {
                UpcomingEventsQueryWithMissedPastEvents(effectiveTimeRange, dateOfEnrollment: dateOfEnrollment) { events in
                    Impl(
                        events: events,
                        showFallbackTasks: showFallbackTasks,
                        eventGroupingConfig: eventGroupingConfig,
                        noTasksMessageLabels: noTasksMessageLabels
                    ) {
                        handleAction($0)
                    }
                }
            } else {
                UpcomingEventsQuery(effectiveTimeRange) { events in
                    Impl(
                        events: events,
                        showFallbackTasks: showFallbackTasks,
                        eventGroupingConfig: eventGroupingConfig,
                        noTasksMessageLabels: noTasksMessageLabels
                    ) {
                        handleAction($0)
                    }
                }
            }
        case .missed:
            MissedEventsQuery(effectiveTimeRange) { events in
                Impl(
                    events: events,
                    showFallbackTasks: false,
                    eventGroupingConfig: eventGroupingConfig,
                    noTasksMessageLabels: noTasksMessageLabels
                ) {
                    handleAction($0)
                }
            }
        }
    }
    
    init(
        mode: Mode,
        timeRange: TimeRange,
        headerConfig: HeaderConfig = .timeRange, // swiftlint:disable:this function_default_parameter_at_end
        eventGroupingConfig: EventGroupingConfig,
        noTasksMessageLabels: NoTasksMessageLabels
    ) {
        self.mode = mode
        self.timeRange = timeRange
        self.headerConfig = headerConfig
        self.eventGroupingConfig = eventGroupingConfig
        self.noTasksMessageLabels = noTasksMessageLabels
    }
}


extension TasksList {
    private func handleAction(_ taskToPerform: Impl.TaskToPerform) {
        switch taskToPerform {
        case let .regular(action, event, context, shouldCompleteEvent):
            handleAction(action, for: event, context: context, shouldComplete: shouldCompleteEvent)
        case .unscheduled(.timedWalkingTest(let test)):
            activeTimedWalkingTest = .init(test: test)
        }
    }
    
    private func handleAction(
        _ action: StudyManager.ScheduledTaskAction,
        for event: Event,
        context: Task.Context.StudyContext,
        shouldComplete: Bool
    ) {
        switch action {
        case .presentInformationalStudyComponent(let component):
            guard let enrollment = studyManager.enrollment(withId: context.enrollmentId),
                  let studyBundle = enrollment.studyBundle,
                  let article = Article(component, in: studyBundle, locale: studyManager.preferredLocale) else {
                logger.error("Error fetching&loading&procesing Article")
                return
            }
            presentedArticle = article
            if shouldComplete {
                // we consider simply presenting the component as being sufficient to complete the event.
                // NOTE ISSUE HERE: completing the event puts it into a state where you can't trigger it again (understandably...)
                // BUT: in this case, we do wanna allow this to happen again! how should we go about this?
                do {
                    try event.complete()
                } catch {
                    logger.error("Was unable to complete() event: \(error)")
                }
            }
        case .answerQuestionnaire(let component):
            guard let enrollment = studyManager.enrollment(withId: context.enrollmentId),
                  let studyBundle = enrollment.studyBundle,
                  let questionnaire = studyBundle.questionnaire(for: component.fileRef, in: studyManager.preferredLocale) else {
                logger.error("Unable to find SPC")
                return
            }
            questionnaireBeingAnswered = .init(
                questionnaire: questionnaire,
                enrollment: enrollment,
                event: event,
                shouldCompleteEvent: shouldComplete
            )
        case .promptTimedWalkingTest(let component):
            activeTimedWalkingTest = .init(test: component.test, event: event, shouldCompleteEvent: shouldComplete)
        case .performCustomActiveTask:
            activeECG = .init {
                do {
                    try event.complete()
                } catch {
                    logger.error("Was unable to complete() event: \(error)")
                }
                activeECG = nil
            }
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
    
    
    private struct UpcomingEventsQueryWithMissedPastEvents<Content: View>: View {
        @MHCTodaysEventsQuery private var events: [Event]
        private let content: @MainActor ([Event]) -> Content
        
        var body: some View {
            content(events)
        }
        
        init(_ timeRange: Range<Date>, dateOfEnrollment: Date, @ViewBuilder content: @escaping @MainActor ([Event]) -> Content) {
            _events = .init(timeRange, dateOfEnrollment: dateOfEnrollment)
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
}


extension TasksList {
    /// Defines how the ``TasksList`` should treat an Event, w.r.t. to its completion status, for the purposes of completing the event, and possibly re-triggering it.
    private struct AllowedEventInteractions: OptionSet {
        static let perform = Self(rawValue: 1 << 0)
        static let complete = Self(rawValue: 1 << 1)
        
        let rawValue: UInt8
        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
    
    private enum EventInteractionConfig: Hashable {
        /// We don't allow the user to perform the event's associated action.
        case disabled
        /// We allow the user to perform the event's associated action.
        /// - parameter shouldComplete: whether the user successfully performing the action should result in the event getting marked as completed.
        case canPerform(shouldComplete: Bool)
        
        var canPerform: Bool {
            switch self {
            case .disabled: false
            case .canPerform: true
            }
        }
        var shouldComplete: Bool {
            switch self {
            case .disabled:
                false
            case .canPerform(let shouldComplete):
                shouldComplete
            }
        }
    }
}


extension TasksList {
    private struct Impl: View {
        typealias SelectionHandler = @MainActor (TaskToPerform) -> Void
        
        /// A task we might offer the user to perform, that isn't associated with any particular scheduled event.
        enum UnscheduledTask: Hashable {
            case timedWalkingTest(TimedWalkingTestConfiguration)
            
            var symbol: SFSymbol {
                switch self {
                case .timedWalkingTest(let test):
                    test.kind.symbol
                }
            }
            
            var displayTitle: LocalizedStringResource {
                switch self {
                case .timedWalkingTest(let test):
                    test.displayTitle
                }
            }
            
            var instructions: LocalizedStringResource? {
                switch self {
                case .timedWalkingTest:
                    nil
                }
            }
            
            var actionLabel: LocalizedStringResource {
                switch self {
                case .timedWalkingTest:
                    "Take Test"
                }
            }
        }
        
        enum TaskToPerform {
            case regular(
                action: StudyManager.ScheduledTaskAction,
                event: Event,
                context: Task.Context.StudyContext,
                shouldCompleteEvent: Bool
            )
            case unscheduled(UnscheduledTask)
        }
        
        private struct SectionedEvents {
            let startOfDay: Date
            let events: [Event]
        }
        
        @Environment(\.calendar) private var cal
        @Environment(Scheduler.self) private var scheduler
        @Environment(StudyManager.self) private var studyManager
        private let events: [Event]
        private let showFallbackTasks: Bool
        private let eventGroupingConfig: TasksList.EventGroupingConfig
        private let noTasksMessageLabels: NoTasksMessageLabels
        private let selectionHandler: SelectionHandler
        
        var body: some View {
            if !events.isEmpty {
                let eventsByDay = eventsByDay
                switch eventGroupingConfig {
                case .none:
                    ForEach(eventsByDay, id: \.startOfDay) { sectionedEvents in
                        ForEach(sectionedEvents.events) { event in
                            Section {
                                tile(for: event)
                            }
                            .listSectionSpacing(.compact)
                        }
                    }
                case .byDay:
                    ForEach(eventsByDay, id: \.startOfDay) { sectionedEvents in
                        Section {
                            ForEach(data: sectionedEvents.events) { (event: Event) in
                                tile(for: event)
                            }
                        } header: {
                            Text(sectionedEvents.startOfDay.formatted(date: .long, time: .omitted))
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        noTasksMessageLabels.title.localizedString(),
                        systemSymbol: .partyPopper,
                        description: Text(noTasksMessageLabels.subtitle)
                    )
                }
                UpcomingTasksTab.sectionHeader(
                    title: "Other Tasks",
                    subtitle: "Always Available"
                )
                fallbackSections
            }
        }
        
        private var eventsByDay: [SectionedEvents] {
            events.chunked { cal.isDate($0.occurrence.start, inSameDayAs: $1.occurrence.start) }
                // SAFETY: the chunking guarantees that the slices aren't empty.
                // we need to use `.first` instead of `[0]`, since the slices share the indices.
                // swiftlint:disable:next force_unwrapping
                .map { SectionedEvents(startOfDay: cal.startOfDay(for: $0.first!.occurrence.start), events: Array($0)) }
        }
        
        @ViewBuilder private var fallbackSections: some View {
            let tasks: [UnscheduledTask] = [
                .timedWalkingTest(.sixMinuteWalkTest),
                .timedWalkingTest(.twelveMinuteRunTest)
            ]
            ForEach(tasks, id: \.self) { task in
                Section {
                    FakeEventTile(
                        symbol: task.symbol,
                        title: task.displayTitle,
                        instructions: task.instructions,
                        actionLabel: task.actionLabel
                    ) {
                        selectionHandler(.unscheduled(task))
                    }
                }
                .listSectionSpacing(.compact)
            }
        }
        
        
        init(
            events: [Event],
            showFallbackTasks: Bool,
            eventGroupingConfig: TasksList.EventGroupingConfig,
            noTasksMessageLabels: NoTasksMessageLabels,
            selectionHandler: @escaping SelectionHandler
        ) {
            self.events = events
            self.showFallbackTasks = showFallbackTasks
            self.eventGroupingConfig = eventGroupingConfig
            self.noTasksMessageLabels = noTasksMessageLabels
            self.selectionHandler = selectionHandler
        }
        
        @ViewBuilder
        private func tile(for event: Event) -> some View {
            if let context = event.task.studyContext,
               let action = event.task.studyScheduledTaskAction {
                let interactions = eventInteractionConfig(for: event)
                InstructionsTile(event, footerVisibility: !event.isCompleted || interactions.canPerform ? .showAlways : .hideIfCompleted) {
                    DefaultTileHeader(event)
                } footer: {
                    EventActionButton(event: event, label: eventButtonTitle(for: event)) {
                        selectionHandler(.regular(
                            action: action,
                            event: event,
                            context: context,
                            shouldCompleteEvent: !event.isCompleted || interactions.shouldComplete
                        ))
                    }
                }
            } else {
                InstructionsTile(event)
            }
        }
        
        private func eventButtonTitle(for event: Event) -> LocalizedStringResource? {
            enum EventActionState {
                case disabled
                case enabled(wouldBeFirstCompletion: Bool)
            }
            let state: EventActionState = switch eventInteractionConfig(for: event) {
            case .disabled: .disabled
            case .canPerform: .enabled(wouldBeFirstCompletion: !event.isCompleted)
            }
            return switch (event.task.category, state) {
            case (.informational, .disabled), (.informational, .enabled(wouldBeFirstCompletion: true)):
                "Read Article"
            case (.informational, .enabled(wouldBeFirstCompletion: false)):
                "Read Article Again"
            case (.questionnaire, .disabled), (.questionnaire, .enabled(wouldBeFirstCompletion: true)):
                "Answer Survey"
            case (.questionnaire, .enabled(wouldBeFirstCompletion: false)):
                "Answer Survey Again"
            case (.timedWalkingTest, .disabled), (.timedWalkingTest, .enabled(wouldBeFirstCompletion: true)),
                (.timedRunningTest, .disabled), (.timedRunningTest, .enabled(wouldBeFirstCompletion: true)):
                "Take Test"
            case (.timedWalkingTest, .enabled(wouldBeFirstCompletion: false)), (.timedRunningTest, .enabled(wouldBeFirstCompletion: false)):
                "Take Test Again"
            case (.customActiveTask(.ecg), _):
                "Take ECG"
            default:
                nil
            }
        }
        
        
        private func eventInteractionConfig(for event: Event) -> EventInteractionConfig {
            let numDaysAway = abs(cal.offsetInDays(from: event.occurrence.start, to: .now))
            let activeTasks = [Task.Category.timedWalkingTest, .timedRunningTest]
            let isActiveTask = event.task.category.map { activeTasks.contains($0) } ?? false
            return if !event.isCompleted {
                // the event in question has not been completed yet.
                if cal.isDateInToday(event.occurrence.start) {
                    if let earliestCompletionDate = event.task.completionPolicy.dateOnceCompletionIsAllowed(for: event),
                       earliestCompletionDate <= .now {
                        .canPerform(shouldComplete: true)
                    } else {
                        .disabled
                    }
                } else {
                    .canPerform(shouldComplete: !isActiveTask && numDaysAway <= 14)
                }
            } else { // the event has already been completed
                // NOTE: the checks in this branch will only every apply to already-completed events that were scheduled for the current day;
                // if they're older than that the TaskList won't be displaying them in the first place.
                if isActiveTask {
                    // we always allow active tasks to be repeated.
                    .canPerform(shouldComplete: false)
                } else {
                    .disabled
                }
            }
        }
    }
}


extension TasksList {
    private struct FakeEventTile: View {
        private let symbol: SFSymbol
        private let title: LocalizedStringResource
        private let subtitle: LocalizedStringResource?
        private let instructions: LocalizedStringResource?
        private let actionLabel: LocalizedStringResource
        private let action: @MainActor () -> Void
        
        var body: some View {
            SimpleTile(alignment: .leading) {
                TileHeader(alignment: .leading) {
                    Image(systemSymbol: symbol)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                        .font(.custom("Task Icon", size: 30, relativeTo: .headline))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                } title: {
                    Text(title)
                } subheadline: {
                    if let subtitle {
                        Text(subtitle)
                    }
                }
            } body: {
                if let instructions {
                    Text(instructions)
                }
            } footer: {
                Button {
                    action()
                } label: {
                    Text(actionLabel)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        
        init(
            symbol: SFSymbol,
            title: LocalizedStringResource,
            subtitle: LocalizedStringResource? = nil, // swiftlint:disable:this function_default_parameter_at_end
            instructions: LocalizedStringResource? = nil, // swiftlint:disable:this function_default_parameter_at_end
            actionLabel: LocalizedStringResource,
            action: @escaping @MainActor () -> Void
        ) {
            self.symbol = symbol
            self.title = title
            self.subtitle = subtitle
            self.instructions = instructions
            self.actionLabel = actionLabel
            self.action = action
        }
    }
}


extension SwiftUI.ForEach {
    // we need this, for some unknown reason, to explicitly select the correct overload in one place above,
    // where, for also unknown reasons, the compiler would otherwise select the @ChartContentBuilder init.
    fileprivate init(
        data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) where Data: RandomAccessCollection, ID == Data.Element.ID, Data.Element: Identifiable, Content: View {
        self.init(data) { content($0) }
    }
}
