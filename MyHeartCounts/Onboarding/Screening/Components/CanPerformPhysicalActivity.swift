//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct CanPerformPhysicalActivity: ScreeningComponent {
    @Environment(OnboardingDataCollection.self)
    private var data
    
    let title: LocalizedStringResource = "Physical Activity"
    
    var body: some View {
        @Bindable var data = data
        SingleChoiceScreeningComponentImpl(
            question: "Are you able to perform physical activities?",
            options: [true, false],
            selection: $data.screening.physicalActivity,
            optionTitle: { $0 ? "Yes" : "No" }
        )
    }
    
    func evaluate(_ data: OnboardingDataCollection) -> Bool {
        data.screening.physicalActivity == true
    }
}
