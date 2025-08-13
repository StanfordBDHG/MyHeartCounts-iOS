//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct OnboardingDisclaimerStep: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    let title: LocalizedStringResource
    let primaryText: LocalizedStringResource
    let learnMoreText: LocalizedStringResource
    @State private var isShowingLearnMoreText = false
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: title)
        } content: {
            Text(primaryText)
        } footer: {
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
        .sheet(isPresented: $isShowingLearnMoreText) {
            NavigationStack {
                ScrollView {
                    Text(learnMoreText)
                        .padding()
                }
                .navigationTitle(String(localized: title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        DismissButton()
                    }
                }
            }
        }
    }
}
