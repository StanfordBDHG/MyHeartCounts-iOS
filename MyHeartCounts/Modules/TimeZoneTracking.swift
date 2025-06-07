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
import class UIKit.UIApplication


final class TimeZoneTracking: Module, @unchecked Sendable {
    @Application(\.logger)
    private var logger
    
    @Dependency(Account.self)
    private var account: Account?
    
    func configure() {
        Task {
            try? await updateTimeZoneInfo()
            let timeChanges = NotificationCenter.default.notifications(named: UIApplication.significantTimeChangeNotification)
            for await _ in timeChanges {
                try? await updateTimeZoneInfo()
            }
        }
    }
    
    
    func updateTimeZoneInfo() async throws {
        guard let account else {
            return
        }
        var newDetails = AccountDetails()
        newDetails.timeZone = TimeZone.current.identifier
        try await account.accountService.updateAccountDetails(.init(modifiedDetails: newDetails))
    }
}


// MARK: Account Key

extension AccountDetails {
    @AccountKey(id: "timeZone", name: "Time Zone", as: String.self)
    var timeZone: String?
}

@KeyEntry(\.timeZone)
extension AccountKeys {}
