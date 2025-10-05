//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import SpeziViews
import SwiftUI


struct OnboardingDisclaimerInfoView: View {
    let icon: SFSymbol
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                content
            }
                .padding(.horizontal)
        }
            .scrollBounceBehavior(.basedOnSize)
    }
    
    @ViewBuilder private var content: some View {
        HStack {
            Spacer()
            Image(systemSymbol: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.accent)
                .accessibilityHidden(true)
                .frame(maxHeight: 150)
                .padding(.vertical, 32)
            Spacer()
        }
        Text(title)
            .font(.title2.bold())
            .multilineTextAlignment(.leading)
            .lineLimit(12)
        Text(description)
            .font(.title3)
            .lineLimit(32)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.secondary)
            .padding(.bottom)
    }
}


#Preview {
    ManagedNavigationStack {
        OnboardingDisclaimerInfoView(
            icon: .heartTextClipboard,
            title: "ONBOARDING_DISCLAIMER_1_TITLE",
            description: "ONBOARDING_DISCLAIMER_1_PRIMARY_TEXT",
        )
    }
}
