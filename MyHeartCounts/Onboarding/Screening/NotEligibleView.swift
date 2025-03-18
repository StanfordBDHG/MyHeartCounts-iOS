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
            OnboardingTitleView(title: "Screening Results")
                .padding(.top, 47)
        } contentView: {
            Form {
                Section {
                    Text("You're sadly not eligible to participate in the My Heart Counts study.")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.zero)
                Section {
                    Link(destination: "https://bdh.stanford.edu") {
                        HStack {
                            Text("Check out our other work")
                            Spacer()
                            Image(systemSymbol: .arrowUpRight)
                                .accessibilityLabel("Link Arrow Symbol")
                        }
                    }
                }
            }
        } actionView: {
            EmptyView()
        }
        .makeBackgroundMatchFormBackground()
        .navigationBarBackButtonHidden()
    }
}
