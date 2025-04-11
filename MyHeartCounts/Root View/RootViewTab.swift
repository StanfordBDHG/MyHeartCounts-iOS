//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziAccount
import SwiftUI


protocol RootViewTab: View { // swiftlint:disable:this file_types_order
    static var tabId: String { get }
    static var tabTitle: LocalizedStringResource { get }
    static var tabSymbol: SFSymbol { get }
    
    init()
}


extension RootViewTab { // swiftlint:disable:this file_types_order
    static var tabId: String {
        String(describing: Self.self)
    }
}


extension RootViewTab { // swiftlint:disable:this file_types_order
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
    @Environment(Account.self)
    private var account: Account?
    @State private var isPresentingAccount = false
    
    var body: some View {
        Group {
            if account != nil {
                AccountButton(isPresented: $isPresentingAccount)
            }
        }
        .sheet(isPresented: $isPresentingAccount) {
            AccountSheet()
        }
    }
}
