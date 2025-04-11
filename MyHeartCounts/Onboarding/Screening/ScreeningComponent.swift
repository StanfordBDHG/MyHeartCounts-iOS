//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


/// The ``SinglePageScreening`` view consists of components, each of which should collect one piece of information from the user, and is placed in its own `Section`.
protocol ScreeningComponent: View { // swiftlint:disable:this file_types_order
    /// The user-displayed title of this component.
    ///
    /// Will be used as the `Section` title in the UI.
    var title: LocalizedStringResource { get }
    
    /// Determines, based on the collected data, whether the user-entered value sasisfies the component's requirements.
    ///
    /// - Note: this function will be called outside of the component being installed in a SwiftUI hierarchy!
    func evaluate(_ data: ScreeningDataCollection) -> Bool
}


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
                    .foregroundStyle(colorScheme.buttonLabelForegroundStyle)
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
    var buttonLabelForegroundStyle: Color {
        self == .dark ? .white : .black
    }
}
