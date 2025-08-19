//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziFoundation
import SpeziStudy
import SpeziViews
import SwiftUI


struct EligibilityScreening: View {
    @Environment(StudyBundleLoader.self)
    private var studyLoader
    
    private let components: [any ScreeningComponent] = [
        AgeAtLeast(style: .toggle, minAge: 18),
        IsFromRegion(allowedRegions: [.unitedStates, .unitedKingdom]),
        SpeaksLanguage(allowedLanguage: .init(identifier: "en_US"))
    ]
    
    var body: some View {
        SinglePageScreening(
            title: "ELIGIBILITY_STEP_TITLE",
            subtitle: "ELIGIBILITY_STEP_SUBTITLE"
        ) {
            components
        } didAnswerAllRequestedFields: { data in
            @MainActor
            func nonnil(_ keyPath: KeyPath<OnboardingDataCollection.Screening, (some Any)?>) -> Bool {
                data.screening[keyPath: keyPath] != nil
            }
            return nonnil(\.dateOfBirth) && nonnil(\.region) && nonnil(\.speaksEnglish)
        } continue: { data, path in
            let isEligible = components.allSatisfy { $0.evaluate(data) }
            if isEligible {
                guard let region = data.screening.region else {
                    // unreachable
                    return
                }
                if !Spezi.didLoadFirebase {
                    // load the firebase modules into Spezi, and give it a couple seconds to fully configure everything
                    // the crux here is that there isn't a mechanism by which Firebase would let us know when it
                    Spezi.loadFirebase(for: region)
                    try? await Task.sleep(for: .seconds(3))
                }
                do {
                    try await studyLoader.update()
                } catch {
                    path.append(customView: UnableToLoadStudyDefinitionStep())
                    return
                }
                path.nextStep()
            } else {
                path.append(customView: NotEligibleView())
            }
        }
    }
}
