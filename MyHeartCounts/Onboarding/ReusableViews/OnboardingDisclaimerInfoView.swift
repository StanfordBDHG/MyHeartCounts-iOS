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


struct OnboardingHeader: View {
    let icon: Image?
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
    
    @ViewBuilder private var content: some View {
        if let icon {
            HStack(alignment: .bottom) {
                Spacer()
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
                    .padding(.vertical, 32)
                Spacer()
            }
            .frame(height: 160)
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
    
    
    init(
        systemSymbol: SFSymbol? = nil, // swiftlint:disable:this function_default_parameter_at_end
        title: LocalizedStringResource,
        description: LocalizedStringResource
    ) {
        self.icon = systemSymbol.map {
            Image(systemSymbol: $0) // swiftlint:disable:this accessibility_label_for_image
        }
        self.title = title
        self.description = description
    }
    
    @_disfavoredOverload
    init(
        icon: Image? = nil, // swiftlint:disable:this function_default_parameter_at_end
        title: LocalizedStringResource,
        description: LocalizedStringResource
    ) {
        self.icon = icon
        self.title = title
        self.description = description
    }
}


#Preview {
    ManagedNavigationStack {
        OnboardingHeader(
            systemSymbol: .heartTextClipboard,
            title: "ONBOARDING_DISCLAIMER_1_TITLE",
            description: "ONBOARDING_DISCLAIMER_1_PRIMARY_TEXT",
        )
    }
}

#Preview {
    ManagedNavigationStack {
        OnboardingHeader(
            systemSymbol: .figureWalkMotion,
            title: "ONBOARDING_DISCLAIMER_2_TITLE",
            description: "ONBOARDING_DISCLAIMER_2_PRIMARY_TEXT",
        )
    }
}

#Preview {
    ManagedNavigationStack {
        OnboardingHeader(
            systemSymbol: .lockSquareStack,
            title: "ONBOARDING_DISCLAIMER_3_TITLE",
            description: "ONBOARDING_DISCLAIMER_3_PRIMARY_TEXT",
        )
    }
}

#Preview {
    ManagedNavigationStack {
        OnboardingHeader(
            title: "ONBOARDING_DISCLAIMER_1_TITLE",
            description: "ONBOARDING_DISCLAIMER_1_PRIMARY_TEXT",
        )
    }
}
