//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct OnboardingDisclaimerStep: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    let icon: SFSymbol
    let title: LocalizedStringResource
    let primaryText: LocalizedStringResource
    let learnMoreText: LocalizedStringResource
    
    @State private var isShowingLearnMoreText = false
    
    
    var body: some View {
        VStack {
            OnboardingDisclaimerInfoView(
                icon: icon,
                title: title,
                description: primaryText
            )
            actionButtons
                .padding(.horizontal)
        }
            .sheet(isPresented: $isShowingLearnMoreText) {
                OnboardingDisclaimerLearnMore(title: title, learnMoreText: learnMoreText)
            }
    }
    
    private var actionButtons: some View {
        OnboardingActionsView(
            primaryTitle: "Continue",
            primaryAction: {
                path.nextStep()
            },
            secondaryTitle: "Learn More",
            secondaryAction: {
                isShowingLearnMoreText = true
            }
        )
    }
}


#Preview {
    ManagedNavigationStack {
        OnboardingDisclaimerStep(
            icon: .heartTextClipboard,
            title: "ONBOARDING_DISCLAIMER_1_TITLE",
            primaryText: "ONBOARDING_DISCLAIMER_1_PRIMARY_TEXT",
            learnMoreText: "ONBOARDING_DISCLAIMER_1_LEARN_MORE_TEXT"
        )
    }
}
