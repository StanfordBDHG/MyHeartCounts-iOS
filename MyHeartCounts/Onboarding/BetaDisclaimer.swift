//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import SpeziOnboarding
import SwiftUI


struct BetaDisclaimer: View {
    @Environment(OnboardingNavigationPath.self)
    private var path
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "Disclaimer")
        } contentView: {
            VStack {
                Image(systemSymbol: .exclamationmarkTriangle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100)
//                        .imageScale(.large)
                    .foregroundStyle(.red)
                    .padding(EdgeInsets(top: 50, leading: 0, bottom: 100, trailing: 0))
                    .accessibilityLabel("Warning Sign Exclamation Mark Symbol")
                Text(
                    """
                    This is the TestFlight beta version of My Heart Counts.
                    
                    Updates may fully reset the app and delete all previously collected data, especially in early stages of development.
                    
                    My Heart Counts will **never** delete anything outside the app itself (e.g., data from Health.app).
                    """
                )
                .font(.system(size: 18))
                .multilineTextAlignment(.center)
            }
        } actionView: {
            OnboardingActionsView("Understood") {
                path.nextStep()
            }
        }
    }
}
