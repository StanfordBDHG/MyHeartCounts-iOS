//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import UserNotifications


/// Intended primarily (exclusively) for debugging purposes.
@MainActor
final class LocalNotifications: Module, EnvironmentAccessible, Sendable {
    func send(
        id: String = UUID().uuidString, // swiftlint:disable:this function_default_parameter_at_end
        title: String,
        body: String,
        level: UNNotificationInterruptionLevel = .active
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = level
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try await UNUserNotificationCenter.current().add(request)
    }
}
