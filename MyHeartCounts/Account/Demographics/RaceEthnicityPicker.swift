//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct RaceEthnicityPicker: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Binding var selection: RaceEthnicity
    
    var body: some View {
        Form {
            makeSection(for: RaceEthnicity.allOptions.filter { $0 != .preferNotToState }, footer: "RACE_SELECTOR_LIST_FOOTER")
            makeSection(for: CollectionOfOne(.preferNotToState))
        }
        .navigationTitle("Race / Ethnicity")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func makeSection(for options: some RandomAccessCollection<RaceEthnicity>, footer: LocalizedStringResource? = nil) -> some View {
        Section {
            ForEach(options, id: \.self) { option in
                makeRow(for: option)
            }
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }
    
    private func makeRow(for option: RaceEthnicity) -> some View {
        Button {
            if option == .preferNotToState {
                selection = option
            } else {
                selection.toggleMembership(of: option)
            }
        } label: {
            HStack {
                Text(option.localizedDisplayTitle)
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
                Spacer()
                if selection.contains(option) {
                    Image(systemSymbol: .checkmark)
                        .fontWeight(.medium)
                        .accessibilityLabel("Selection Checkmark")
                }
            }
        }
    }
}
