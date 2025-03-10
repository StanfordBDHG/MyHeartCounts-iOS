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
    @Environment(\.locale)
    private var locale
    @Environment(ScreeningDataCollection.self)
    private var data
    
    let title: LocalizedStringResource = "Language"
    let allowedLanguage: Locale.Language
    
    var body: some View {
        @Bindable var data = data
        SingleChoiceScreeningComponentImpl(
            question: "Do you speak \(allowedLanguage.localizedName(in: locale))?",
            options: [true, false],
            selection: $data.speaksEnglish,
            optionTitle: { $0 ? "Yes" : "No" }
        )
    }
    
    func evaluate(_ data: ScreeningDataCollection) -> Bool {
        data.speaksEnglish == true
    }
}
