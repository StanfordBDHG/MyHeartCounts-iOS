//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SwiftUI


struct OnboardingPage<Content: View, Footer: View>: View {
    private let symbol: SFSymbol?
    private let title: LocalizedStringResource
    private let description: LocalizedStringResource
    private let content: Content
    private let footer: Footer
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                        OnboardingHeader(systemSymbol: symbol, title: title, description: description)
                            .padding(.top, symbol == nil ? 32 : 0)
                        content
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
                .scrollBounceBehavior(.basedOnSize)
            Spacer(minLength: 8)
                .border(Color.blue, width: 1)
            footer
                .padding(.horizontal)
        }
        .navigationTitle(Text(verbatim: ""))
        .toolbar(.visible)
    }
    
    init(
        symbol: SFSymbol? = nil,
        title: LocalizedStringResource,
        description: LocalizedStringResource,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.symbol = symbol
        self.title = title
        self.description = description
        self.content = content()
        self.footer = footer()
    }
}
