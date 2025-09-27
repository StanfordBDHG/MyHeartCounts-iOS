//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import SFSafeSymbols
import SpeziFoundation
import SpeziScheduler
import SpeziStudy
import SpeziStudyDefinition
import SwiftUI


struct AlwaysAvailableActiveTasksMenu: View {
    @AlwaysAvailableTasks private var alwaysAvailableTasks
    @PerformTask private var performTask
    
    var body: some View {
        Menu {
            ForEach(alwaysAvailableTasks.taskActions(), id: \.self) { actions in
                ForEach(actions, id: \.self) { action in
                    Button {
                        performTask(action)
                    } label: {
                        Label(action.title, systemSymbol: action.symbol)
                    }
                }
                Divider()
            }
        } label: {
            Label("Perform Active Task", systemSymbol: .plus)
        }
    }
}


@propertyWrapper
@MainActor
struct AlwaysAvailableTasks: DynamicProperty { // TODO rename AlwaysAvailableActions?
    @Environment(\.calendar) private var cal
    @Environment(Scheduler.self) private var scheduler
    @Environment(StudyManager.self) private var studyManager
    
    var wrappedValue: Self {
        self
    }
    
    func taskActions(excludingBasedOn events: [Event] = []) -> [[PerformTask.Task.Action]] {
        // All actions we want to offer as "always available"
        let allActions: [[PerformTask.Task.Action]] = [
            [.ecg],
            [.timedWalkTest(.sixMinuteWalkTest), .timedWalkTest(.twelveMinuteRunTest)]
        ]
        guard !events.isEmpty else {
            return allActions
        }
        // filter out anything that's already prompted above
        return allActions.compactMap { (actions: [PerformTask.Task.Action]) in
            let actions = actions.filter { (action: PerformTask.Task.Action) -> Bool in
                switch action {
                case .ecg:
                    !events.contains { $0.task.category == .customActiveTask(.ecg) }
                case .timedWalkTest(let testConfig):
                    !events.contains { event in
                        switch event.task.studyScheduledTaskAction {
                        case .promptTimedWalkingTest(let component):
                            component.test == testConfig
                        default:
                            false
                        }
                    }
                case .answerQuestionnaire(let questionnaire):
                    !events.contains { event in
                        switch event.task.studyScheduledTaskAction {
                        case .answerQuestionnaire(let component):
                            studyManager.studyEnrollments.first?.studyBundle?.questionnaire(for: component.fileRef, in: studyManager.preferredLocale)?.id == questionnaire.id
                        default:
                            false
                        }
                    }
                case .article(let article):
                    !events.contains { event in
                        switch event.task.studyScheduledTaskAction {
                        case .presentInformationalStudyComponent(let component):
                            (studyManager.studyEnrollments.first?.studyBundle?.resolve(component.fileRef, in: studyManager.preferredLocale))
                                .flatMap { try? Data(contentsOf: $0) }
                                .flatMap { String(data: $0, encoding: .utf8) }
                                .flatMap { try? MarkdownDocument.Metadata(parsing: $0) }
                                .map { $0["id"] == article.id.uuidString } ?? false
                        default:
                            false
                        }
                    }
                }
            }
            return actions.isEmpty ? nil : actions
        }
    }
}
