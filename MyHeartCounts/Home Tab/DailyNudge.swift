//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
import Foundation
import SwiftUI


@MainActor
@propertyWrapper
struct DailyNudge: DynamicProperty {
    struct Nudge: Sendable {
        let title: String
        let message: String
    }
    
    @Environment(\.calendar)
    private var cal
    
    @MHCFirestoreQuery(
        collection: .user(path: "notificationHistory"),
        sortBy: [.init(fieldName: "originalTimestamp", order: .reverse)],
        limit: 1,
        decode: { try? $0.data(as: MHCUserNotification.self) }
    )
    private var notifications: [MHCUserNotification]
    
    var wrappedValue: Nudge? {
        guard let notificaton = notifications.first else {
            return nil
        }
        guard cal.isDateInToday(notificaton.originalTimestamp) || cal.isDateInYesterday(notificaton.originalTimestamp) else {
            return nil
        }
        return Nudge(title: notificaton.title, message: notificaton.body)
    }
}
