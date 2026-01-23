//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MyHeartCountsShared
import SwiftUI


struct SpeaksLanguage: ScreeningComponent {
    struct AllowedLanguage {
        fileprivate let language: Locale.Language // swiftlint:disable:this type_contents_order
        
        /// A language requirement that simply refers to the current language of the app.
        static var current: Self {
            .specific(Locale.current.language)
        }
        
        static func specific(_ language: Locale.Language) -> Self {
            Self(language: language)
        }
    }
    
    // swiftlint:disable attributes
    @Environment(\.locale) private var locale
    @Environment(OnboardingDataCollection.self) private var data
    // swiftlint:enable attributes
    
    let title: LocalizedStringResource = "Language"
    let allowedLanguage: AllowedLanguage
    
    var body: some View {
        @Bindable var data = data
        SingleChoiceScreeningComponentImpl(
            "Can you read and understand \(allowedLanguage.language.localizedName(in: locale)) in order to provide informed consent and follow instructions?",
            options: [true, false],
            selection: $data.screening.speaksEnglish,
            optionTitle: { $0 ? "Yes" : "No" }
        )
    }
    
    func evaluate(_ data: OnboardingDataCollection) -> Bool {
        data.screening.speaksEnglish == true
    }
}
