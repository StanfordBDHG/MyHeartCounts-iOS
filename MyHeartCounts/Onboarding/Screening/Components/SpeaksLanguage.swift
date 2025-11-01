//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct SpeaksLanguage: ScreeningComponent {
    // swiftlint:disable attributes
    @Environment(\.locale) private var locale
    @Environment(OnboardingDataCollection.self) private var data
    // swiftlint:enable attributes
    
    let title: LocalizedStringResource = "Language"
    let allowedLanguage: Locale.Language
    
    var body: some View {
        @Bindable var data = data
        SingleChoiceScreeningComponentImpl(
            "Can you read and understand \(allowedLanguage.localizedName(in: locale)) in order to provide informed consent and follow instructions?",
            options: [true, false],
            selection: $data.screening.speaksEnglish,
            optionTitle: { $0 ? "Yes" : "No" }
        )
    }
    
    func evaluate(_ data: OnboardingDataCollection) -> Bool {
        data.screening.speaksEnglish == true
    }
}
