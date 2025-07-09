//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import SpeziFoundation
import SpeziOnboarding
import SwiftUI


extension OnboardingInformationView {
    init(@ArrayBuilder<OnboardingInformationView.Content> _ areas: () -> [OnboardingInformationView.Content]) {
        self.init(areas: areas())
    }
}

extension OnboardingInformationView.Content {
    init(symbol: SFSymbol, title: LocalizedStringResource, content: some StringProtocol) {
        self.init(
            icon: Image(systemSymbol: symbol),
            title: String(localized: title),
            description: content
        )
    }
}
