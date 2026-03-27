//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziAccount


final class LanguageTracking: ServiceModule, @unchecked Sendable {
    @Dependency(Account.self)
    private var account: Account?
    
    func run() async {
        try? await updateLanguageInfo()
        let localeChanges = NotificationCenter.default.notifications(named: NSLocale.currentLocaleDidChangeNotification)
        for await _ in localeChanges {
            try? await updateLanguageInfo()
        }
    }
    
    private func updateLanguageInfo() async throws {
        guard let account else {
            return
        }
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        var newDetails = AccountDetails()
        newDetails.language = languageCode
        try await account.accountService.updateAccountDetails(.init(modifiedDetails: newDetails))
    }
}

