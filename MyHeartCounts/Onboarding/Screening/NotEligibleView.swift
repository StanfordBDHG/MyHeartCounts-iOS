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


struct NotEligibleView: View {
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "INELIGIBLE_TITLE")
                .padding(.top, 47)
        } content: {
            Form {
                Section {
                    Text("INELIGIBLE_SUBTITLE")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.zero)
                Section {
                    Link(destination: "https://bdh.stanford.edu") {
                        HStack {
                            Text("INELIGIBLE_LEARN_MORE")
                            Spacer()
                            Image(systemSymbol: .arrowUpRight)
                                .accessibilityLabel("Link Arrow Symbol")
                        }
                    }
                }
            }
        } footer: {
            EmptyView()
        }
        .makeBackgroundMatchFormBackground()
    }
}
