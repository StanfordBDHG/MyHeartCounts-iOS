//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct NotEligibleView: View {
    var body: some View {
        OnboardingPage(
            symbol: .documentBadgeEllipsis,
            title: "INELIGIBLE_TITLE",
            description: "INELIGIBLE_SUBTITLE",
            content: {
                EmptyView()
            },
            footer: {
                Link(destination: MyHeartCounts.website) {
                    HStack {
                        Text("INELIGIBLE_LEARN_MORE")
                        Spacer()
                        Image(systemSymbol: .arrowUpRight)
                            .accessibilityHidden(true)
                    }
                    .bold()
                    .padding(12)
                }
                .buttonStyleGlassProminent()
            }
        )
        .makeBackgroundMatchFormBackground()
    }
}


#Preview {
    NotEligibleView()
}
