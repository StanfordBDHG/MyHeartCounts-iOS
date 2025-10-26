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


protocol DemographicsSelectableSimpleValue: Identifiable, Hashable {
    static var notSet: Self { get }
    static var preferNotToState: Self { get }
    
    /// all options, except for ``notSet`` and ``preferNotToState``.
    static var options: [Self] { get }
    
    var displayTitle: LocalizedStringResource { get }
}


struct DemographicsSingleSelectionPicker<Value: DemographicsSelectableSimpleValue>: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Binding var selection: Value
    
    var body: some View {
        Form {
            Section {
                ForEach(Value.options) { option in
                    makeRow(for: option)
                }
            }
            Section {
                makeRow(for: .preferNotToState)
            }
        }
    }
    
    @ViewBuilder
    private func makeRow(for option: Value) -> some View {
        Button {
            selection = option
        } label: {
            HStack {
                Text(option.displayTitle)
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
                Spacer()
                if option == selection {
                    Image(systemSymbol: .checkmark)
                        .fontWeight(.medium)
                        .tint(.blue)
                        .accessibilityLabel("Selection Checkmark")
                }
            }
            .contentShape(Rectangle())
        }
    }
}
