//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import MarkdownUI
import SFSafeSymbols
import SwiftUI


struct OnboardingIconGridRow: View {
    let icon: SFSymbol
    let text: LocalizedStringResource
    
    var body: some View {
        GridRow {
            Image(systemSymbol: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
                .foregroundStyle(.tint)
                .gridCellAnchor(.topLeading)
                .frame(width: 42, alignment: .topLeading)
            HStack {
                // one of the elements contains a bullet list;
                // we use the Markdown view here to have this properly indented (makes it easier to read)
                Markdown(String(localized: text))
                    .markdownTextStyle(\.text) {
                        ForegroundColor(.secondary)
                    }
                    .markdownBlockStyle(\.list) { config in
                        config.label
                            .padding([.leading, .top], -12)
                    }
                    .padding(.bottom)
                Spacer()
            }
        }
    }
}


#Preview {
    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        if #available(iOS 26, *) {
            OnboardingIconGridRow(
                icon: ._7Calendar,
                text: "FINAL_ENROLLMENT_STEP_MESSAGE_SEVEN_DAYS"
            )
        }
        OnboardingIconGridRow(
            icon: .deskclock,
            text: "FINAL_ENROLLMENT_STEP_MESSAGE_EVERY_DAY"
        )
    }
}
