//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//


extension LocalPreferenceKey {
    /// A `Bool` flag indicating of the onboarding was completed.
    static var onboardingFlowComplete: LocalPreferenceKey<Bool> {
        .make("onboardingFlowComplete", default: false)
    }
}
