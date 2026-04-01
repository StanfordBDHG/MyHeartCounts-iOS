//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
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
        let notifications = NotificationCenter.default.notifications(
            named: NSLocale.currentLocaleDidChangeNotification // swiftlint:disable:this legacy_objc_type
        )
        for await _ in notifications {
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
