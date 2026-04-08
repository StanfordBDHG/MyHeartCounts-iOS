//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SpeziAccount
import enum SwiftUI.ScenePhase


final class ActivityTracking: Module, @unchecked Sendable {
    // swiftlint:disable attributes
    @Application(\.logger) private var logger
    @Dependency(Lifecycle.self) private var lifecycle
    @Dependency(Account.self) private var account
    // swiftlint:enable attributes
    
    func configure() {
        lifecycle.onChange(of: \.scenePhase, initial: true) { _, newValue in
            if newValue == .active {
                Task {
                    try await self.updateLastSeen()
                }
            }
        }
    }
    
    private func updateLastSeen() async throws {
        logger.notice("Updating last seen date")
        var newDetails = AccountDetails()
        newDetails.lastActiveDate = Date()
        try await account.accountService.updateAccountDetails(.init(modifiedDetails: newDetails))
    }
}
