//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

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
                Text(text)
                    .font(.body)
                    .lineLimit(32)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
                Spacer()
            }
        }
    }
    
    
    init(icon: SFSymbol, text: LocalizedStringResource) {
        self.icon = icon
        self.text = text
    }
}


#Preview {
    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        OnboardingIconGridRow(
            icon: SFSymbol(rawValue: "7.calendar"),
            text: "FINAL_ENROLLMENT_STEP_MESSAGE_SEVEN_DAYS"
        )
        OnboardingIconGridRow(
            icon: .deskclock,
            text: "FINAL_ENROLLMENT_STEP_MESSAGE_EVERY_DAY"
        )
    }
}
