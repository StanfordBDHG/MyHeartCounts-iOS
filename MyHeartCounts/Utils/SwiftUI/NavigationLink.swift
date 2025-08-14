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


struct TitleAndSymbolNavigationLinkLabel: View {
    @Environment(\.colorScheme) private var colorScheme // swiftlint:disable:this attributes
    private let symbol: SFSymbol
    private let title: LocalizedStringResource
    
    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemSymbol: symbol)
                .foregroundStyle(colorScheme.textLabelForegroundStyle)
                .accessibilityHidden(true)
        }
    }
    
    nonisolated fileprivate init(symbol: SFSymbol, title: LocalizedStringResource) {
        self.symbol = symbol
        self.title = title
    }
}


extension NavigationLink {
    init(
        symbol: SFSymbol,
        _ title: LocalizedStringResource,
        @ViewBuilder destination: () -> Destination
    ) where Destination: View, Label == TitleAndSymbolNavigationLinkLabel {
        self.init {
            destination()
        } label: {
            TitleAndSymbolNavigationLinkLabel(symbol: symbol, title: title)
        }
    }
}
