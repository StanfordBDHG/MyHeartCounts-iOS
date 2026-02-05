//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import SpeziScheduler
import SpeziSchedulerUI
import SpeziViews
import SwiftUI


extension HomeTab {
    struct PromptedActionButton: View {
        @Environment(MyHeartCountsStandard.self)
        private var standard
        
        @PromptedActions private var promptedActions
        
        let action: PromptedAction
        @Binding var viewState: ViewState
        
        var body: some View {
            let content = action.content
            LabeledButton(
                symbol: content.symbol,
                title: content.title,
                subtitle: content.message,
                state: $viewState,
                action: { try await action(standard.spezi) }
            )
            .contextMenu {
                Button(role: .destructive) {
                    $promptedActions.reject(action.id)
                } label: {
                    Label("Stop Suggesting This", systemSymbol: .minusCircle)
                }
            }
        }
    }
}
