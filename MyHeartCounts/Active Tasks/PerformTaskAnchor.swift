//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import class ModelsR4.Questionnaire
import ResearchKitSwiftUI
import SFSafeSymbols
import SpeziQuestionnaire
import SpeziScheduler
import SpeziStudy
import SpeziStudyDefinition
import SwiftUI


@Observable
@MainActor
private final class MHCCurrentlyActiveTask: Sendable {
    fileprivate var task: PerformTask.Task?
}


@propertyWrapper
@MainActor
struct PerformTask: DynamicProperty {
    struct Task {
        enum Action: Hashable {
            case answerQuestionnaire(Questionnaire)
            case article(Article)
            case timedWalkTest(TimedWalkingTestConfiguration)
            case ecg
        }
        fileprivate let action: Action
        fileprivate let completionHandler: @Sendable @MainActor (_ success: Bool) -> Void
    }
    
    @Environment(\.calendar) private var cal
    @Environment(MHCCurrentlyActiveTask.self) private var currentlyActiveTask
    @Environment(Scheduler.self) private var scheduler
    
    var wrappedValue: Self {
        self
    }
    
    func callAsFunction(_ action: Task.Action) async -> Bool {
        guard currentlyActiveTask.task == nil else {
            print("Error: Attempted to initiate a new active task, while one was already ongoing. Ignoring.")
            return false
        }
        return await withCheckedContinuation { continuation in
            currentlyActiveTask.task = .init(action: action) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    
    func callAsFunction(_ action: Task.Action, context: Event? = nil) {
        _Concurrency.Task {
            guard await self(action) else {
                return
            }
            if let context {
                try context.complete()
            } else {
                try reportCompletion(of: action)
            }
        }
    }
    
    
    func reportCompletion(of action: Task.Action) throws {
        // see if we can find a scheduled event with the same action, and mark it as complete if possible.
        let eventQueryTimeRange: Range<Date> = cal.startOfDay(for: .now)..<cal.date(byAdding: .weekOfYear, value: 1, to: cal.startOfDay(for: .now))!
        let candidateEvents = try scheduler.queryEvents(for: eventQueryTimeRange).lazy.filter { !$0.isCompleted }
        let event: Event? = switch action {
        case .ecg:
            candidateEvents.first { event in
                event.task.category == .customActiveTask(.ecg)
            }
        case .timedWalkTest(let test):
            candidateEvents.first { event in
                switch event.task.studyScheduledTaskAction {
                case .promptTimedWalkingTest(let component):
                    component.test == test
                default:
                    false
                }
            }
        case .article, .answerQuestionnaire:
            nil // ignored // TODO explain why!
        }
        guard let event else {
            return
        }
//        try event.complete()
    }
}


private struct PerformTaskModifier: ViewModifier {
    @Environment(MyHeartCountsStandard.self)
    private var standard
    
    @Environment(MHCCurrentlyActiveTask.self)
    private var currentlyActiveTask
    
    func body(content: Content) -> some View {
        @Bindable var currentlyActiveTask = currentlyActiveTask
        content
            .sheet(item: $currentlyActiveTask.task, id: \.action) { task in
                switch task.action {
                case .answerQuestionnaire(let questionnaire):
                    QuestionnaireView(questionnaire: questionnaire, cancelBehavior: .cancel) { result in
                        switch result {
                        case .completed(let response):
                            await standard.add(response)
                            task.completionHandler(true)
                        case .cancelled, .failed:
                            task.completionHandler(false)
                        }
                        currentlyActiveTask.task = nil
                    }
                case .article(let article):
                    ArticleSheet(article: article)
                        .onAppear {
                            // we consider simply presenting the component as being sufficient to complete the event.
                            // NOTE ISSUE HERE: completing the event puts it into a state where you can't trigger it again (understandably...)
                            // BUT: in this case, we do wanna allow this to happen again! how should we go about this?
                            task.completionHandler(true)
                        }
                case .timedWalkTest(let test):
                    NavigationStack {
                        TimedWalkingTestView(test) { result in
                            task.completionHandler(result != nil)
                        }
                    }
                case .ecg:
                    NavigationStack {
                        ECGInstructionsSheet(shouldOfferManualCompletion: true) { success in
                            task.completionHandler(success)
                        }
                    }
                }
            }
    }
}

extension View {
    /// Designates the view as an anchor for initiating user-prompted tasks, within this part of the view hierarchy.
    ///
    /// Apply this modifier to those parts of the view hierarchy that need to be able to present sheets in response to task actions being initiated via the ``PerformTask`` API.
    /// The modifier is applied once to the root view, and additionally needs to be applied to all views presented as sheets that also need to be able to trigger tasks.
    /// If a task is triggered from within sheet whose view isn't also a taskPerformingAnchor, initiating the task will lead to unexpected behaviour,
    /// causing the first sheet to get dismissed so that the second (task specific) sheet can be displayed.
    func taskPerformingAnchor() -> some View {
        self
            .modifier(PerformTaskModifier())
            .environment(MHCCurrentlyActiveTask())
    }
}


extension PerformTask.Task.Action {
    var title: String {
        switch self {
        case .answerQuestionnaire(let questionnaire):
            questionnaire.title?.value?.string ?? "Questionnaire"
        case .article(let article):
            article.title
        case .timedWalkTest(let test):
            String(localized: test.displayTitle)
        case .ecg:
            String(localized: "ECG")
        }
    }
    
    var subtitle: String? {
        switch self {
        case .answerQuestionnaire(let questionnaire):
            questionnaire.purpose?.value?.string
        case .article:
            nil // TODO lede?
        case .timedWalkTest:
            nil
        case .ecg:
            String(localized: "Electrocardiogram")
        }
    }
    
    var symbol: SFSymbol {
        switch self {
        case .answerQuestionnaire:
            .listBulletClipboard
        case .article:
            .textRectanglePage
        case .timedWalkTest(let test):
            test.kind.symbol
        case .ecg:
            .waveformPathEcgRectangle
        }
    }
    
    /// The text displayed in a button that initiates this action
    var actionLabel: LocalizedStringResource {
        switch self {
        case .answerQuestionnaire:
            "Answer Questionnaire"
        case .article:
            "Read"
        case .timedWalkTest:
            "Take Test"
        case .ecg:
            "Take ECG"
        }
    }
}
