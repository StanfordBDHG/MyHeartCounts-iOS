//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SwiftUI


struct AlwaysAvailableTaskActionsMenu: View {
    @AlwaysAvailableTaskActions private var alwaysAvailableTaskActions
    @PerformTask private var performTask
    
    var body: some View {
        Menu {
            ForEach(alwaysAvailableTaskActions.taskActions(), id: \.self) { actions in
                ForEach(actions, id: \.self) { action in
                    Button {
                        performTask(action)
                    } label: {
                        Label(String(localized: action.title), systemSymbol: action.symbol)
                    }
                }
                Divider()
            }
        } label: {
            Label("Perform Always Available Task", systemSymbol: .plus)
        }
    }
}
