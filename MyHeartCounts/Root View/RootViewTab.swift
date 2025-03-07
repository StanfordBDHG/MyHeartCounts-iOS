//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziAccount
import SwiftUI
import SFSafeSymbols


protocol RootViewTab: View {
    static var tabId: String { get }
    static var tabTitle: LocalizedStringResource { get }
    static var tabSymbol: SFSymbol { get }
    
    init()
}


extension RootViewTab {
    static var tabId: String {
        String(describing: Self.self)
    }
}


extension RootViewTab {
    /// A `ToolbarItem` consisting of a Button which will present the account management sheet.
    ///
    /// ``RootViewTab``s should include this in their respective toolbars.
    var accountToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            AccountToolbarButton()
        }
    }
}


private struct AccountToolbarButton: View {
    @Environment(Account.self) private var account: Account?
    @State var isPresentingAccount = false
    
    var body: some View {
        if account != nil {
            AccountButton(isPresented: $isPresentingAccount)
                .sheet(isPresented: $isPresentingAccount) {
                    AccountSheet()
                }
        }
    }
}
