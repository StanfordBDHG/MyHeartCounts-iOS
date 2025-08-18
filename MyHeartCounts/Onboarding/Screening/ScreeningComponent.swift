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


struct SingleChoiceScreeningComponentImpl<Option: Hashable>: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    let question: LocalizedStringResource
    let options: [Option]
    @Binding var selection: Option?
    let optionTitle: (Option) -> LocalizedStringResource
    
    var body: some View {
        Text(question)
            .fontWeight(.medium)
        ForEach(options, id: \.self) { option in
            makeRow(for: option)
        }
    }
    
    private func makeRow(for option: Option) -> some View {
        Button {
            if selection == option {
                // deselect
                selection = nil
            } else {
                // select
                selection = option
            }
        } label: {
            HStack {
                Text(optionTitle(option))
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
                if selection == option {
                    Spacer()
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                        .accessibilityLabel("Selection Checkmark")
                }
            }
            .contentShape(Rectangle())
        }
    }
}


extension ColorScheme {
    var textLabelForegroundStyle: Color {
        self == .dark ? .white : .black
    }
}
