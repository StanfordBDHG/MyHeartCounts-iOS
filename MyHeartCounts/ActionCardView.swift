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


struct ActionCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let card: MHC.ActionCard
    let actionHandler: @MainActor (MHC.ActionCard.Action) async -> Void
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        switch card.content {
        case .event(let event):
            content(for: event)
        case .simple(let simpleContent):
            content(for: simpleContent)
        }
    }
    
    
    private func content(for event: Event) -> some View {
        InstructionsTile(event, alignment: .leading) {
            DefaultTileHeader(event, alignment: .leading)
        } footer: {
            EventActionButton(event: event) {
                // TODO
                fatalError()
            }
        } more: {
            Text("MORE")
        }
//            .taskCategoryAppearance(for: .questionnaire, label: "Hola")
    }
    
    
    private func content(for content: MHC.ActionCard.SimpleContent) -> some View {
        AsyncButton(state: $viewState) {
            await actionHandler(card.action)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        if let symbol = content.symbol {
                            Image(systemSymbol: symbol)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .bold()
                                .frame(width: 20, height: 20)
                        }
                        Text(content.title)
                            .font(.headline.bold())
                        Spacer()
                    }
                    Text(content.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
//                switch card.trailingAccessory {
//                case .none:
//                    EmptyView()
//                case .disclosureIndicator:
//                    DisclosureIndicator()
//                }
            }
        }//.buttonStyle(.plain)
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
