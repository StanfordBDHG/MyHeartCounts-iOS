//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order discouraged_optional_boolean

import Foundation
import SpeziFoundation
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct ComprehensionScreening: View {
    var body: some View {
        SinglePageScreening(
            title: "COMPREHENSION_STEP_TITLE",
            subtitle: "COMPREHENSION_STEP_SUBTITLE"
        ) {
            Question(
                question: "COMPREHENSION_QUESTION_1",
                storage: \.seekHelpIfNotFeelingWell
            )
            Question(
                question: "COMPREHENSION_QUESTION_2",
                storage: \.studyParticipationIsVoluntary
            )
            Question(
                question: "COMPREHENSION_QUESTION_3",
                storage: \.canStopParticipatingAtAnyTime
            )
        } didAnswerAllRequestedFields: { data in
            let isTrue = { (keyPath: KeyPath<OnboardingDataCollection.Comprehension, Bool?>) in
                data.comprehension[keyPath: keyPath] == true
            }
            return isTrue(\.seekHelpIfNotFeelingWell) && isTrue(\.studyParticipationIsVoluntary) && isTrue(\.canStopParticipatingAtAnyTime)
        } continue: { _, path in
            path.nextStep()
        }
    }
}


private struct Question: ScreeningComponent {
    @Environment(OnboardingDataCollection.self)
    private var onboardingData
    
    let title: LocalizedStringResource = ""
    let question: LocalizedStringResource
    let storage: WritableKeyPath<OnboardingDataCollection.Comprehension, Bool?>
    
    var body: some View {
        SingleChoiceScreeningComponentImpl(
            question,
            options: [true, false],
            selection: Binding<Bool?> {
                onboardingData.comprehension[keyPath: storage]
            } set: {
                onboardingData.comprehension[keyPath: storage] = $0
            },
            optionTitle: { $0 ? "True" : "False" }
        )
        .accessibilityIdentifier("Consent Comprehension: \(String(localized: title))")
    }
    
    func evaluate(_ data: OnboardingDataCollection) -> Bool {
        data.comprehension[keyPath: storage] == true
    }
}


#Preview {
    ManagedNavigationStack {
        ComprehensionScreening()
    }
    .environment(OnboardingDataCollection())
}
