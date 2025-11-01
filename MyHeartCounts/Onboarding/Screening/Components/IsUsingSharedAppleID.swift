//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct IsUsingSharedAppleID: ScreeningComponent {
    // swiftlint:disable attributes
    @Environment(\.locale) private var locale
    @Environment(OnboardingDataCollection.self) private var data
    // swiftlint:enable attributes
    
    let title: LocalizedStringResource = "Apple ID Sharing"
    
    var body: some View {
        @Bindable var data = data
        SingleChoiceScreeningComponentImpl(
            "Are you using a shared Apple ID?",
            explanation: """
                My Heart Counts does not access your Apple ID in any way; but using a shared account might cause inaccuracies in Health data collection.
                """,
            selection: $data.screening.sharedAppleID,
            style: .list
        )
    }
    
    func evaluate(_ data: OnboardingDataCollection) -> Bool {
        data.screening.sharedAppleID == false
    }
}
