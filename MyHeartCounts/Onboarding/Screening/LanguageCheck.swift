//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziOnboarding
import SwiftUI


struct LanguageCheck: View {
    let language: Locale.Language
    
    var body: some View {
        let langName = Locale.current.localizedString(
            forLanguageCode: language.languageCode?.identifier ?? language.minimalIdentifier
        ) ?? language.minimalIdentifier
        BooleanScreeningStep(
            title: "Language",
            question: "Do you speak \(langName)?",
            explanation: "My Heart Counts is currently only available in \(langName)"
        )
    }
}
