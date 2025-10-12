//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziAccount
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct AccountOnboarding: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    var body: some View {
        AccountSetup { _ in
            Task {
                // Placing the nextStep() call inside this task will ensure that the sheet dismiss animation is
                // played till the end before we navigate to the next step.
                path.nextStep()
            }
        } header: {
            AccountSetupHeader()
        } continue: {
            OnboardingActionsView("Next") {
                path.nextStep()
            }
        }
        .navigationTitle(Text(verbatim: ""))
        .toolbar(.visible)
    }
}
