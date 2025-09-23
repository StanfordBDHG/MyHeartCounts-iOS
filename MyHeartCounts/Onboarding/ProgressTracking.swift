//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziAccount
import SwiftUI


struct OnboardingStep: RawRepresentableAccountKey {
    let rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
}


private struct OnboardingStepModifier: ViewModifier {
    // swiftlint:disable attributes
    @Environment(\.isInOnboardingFlow) private var isInOnboarding
    @Environment(Account.self) private var account: Account?
    // swiftlint:enable attributes
    
    let step: OnboardingStep
    
    func body(content: Content) -> some View {
        content.task {
            guard isInOnboarding, let account else {
                print("Skipping onboarding progress report", isInOnboarding, self.account)
                return
            }
            do {
                var details = AccountDetails()
                details.mostRecentOnboardingStep = step
                let modifications = try AccountModifications(modifiedDetails: details)
                try await account.accountService.updateAccountDetails(modifications)
            } catch {
                print("Error updating most recent onboarding step: \(error)")
            }
        }
    }
}


extension AccountDetails {
    @AccountKey(
        id: "mostRecentOnboardingStep",
        name: "",
        category: .other,
        options: .mutable,
        as: OnboardingStep.self,
        initial: .default(.init(rawValue: ""))
    )
    var mostRecentOnboardingStep: OnboardingStep?
}


@KeyEntry(\.mostRecentOnboardingStep)
extension AccountKeys {}


extension EnvironmentValues {
    @Entry var isInOnboardingFlow: Bool = false
}


extension View {
    func onboardingStep(_ step: OnboardingStep) -> some View {
        self.modifier(OnboardingStepModifier(step: step))
    }
}
