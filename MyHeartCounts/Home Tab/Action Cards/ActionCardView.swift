//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import SpeziScheduler
import SpeziSchedulerUI
import SpeziViews
import SwiftUI


/// View that displays an ``StudyManager/ActionCard``.
struct ActionCardView: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    private let card: ActionCard
    private let actionHandler: @MainActor (ActionCard.Action) async -> Void
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        switch card.content {
        case .event(let event):
            content(for: event)
        case .custom(let simpleContent):
            content(for: simpleContent)
        }
    }
    
    init(card: ActionCard, actionHandler: @MainActor @escaping (ActionCard.Action) async -> Void) {
        self.card = card
        self.actionHandler = actionHandler
    }
    
    private func content(for event: Event) -> some View {
        InstructionsTile(event, alignment: .leading) {
            DefaultTileHeader(event, alignment: .leading)
        } footer: {
            EventActionButton(event: event) {
                guard let action = event.task.studyScheduledTaskAction else {
                    print("Unable to fetch associated action.")
                    return
                }
                // https://github.com/StanfordSpezi/SpeziScheduler/issues/54
                _Concurrency.Task {
                    await actionHandler(.scheduledTaskAction(action))
                }
            }
        } more: {
            Text("MORE")
        }
    }
    
    private func content(for content: ActionCard.SimpleContent) -> some View {
        AsyncButton(state: $viewState) {
            await actionHandler(card.action)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        if let symbol = content.symbol {
                            Image(symbol)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .bold()
                                .frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                        }
                        Text(content.title)
                            .font(.headline.bold())
                        Spacer()
                    }
                    Text(content.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint({ () -> Color in
            switch colorScheme {
            case .light:
                Color.black
            case .dark:
                Color.white
            @unknown default:
                Color.black
            }
        }())
    }
}
