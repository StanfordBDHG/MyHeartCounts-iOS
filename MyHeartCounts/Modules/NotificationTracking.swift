//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
import Foundation
import OSLog
import Spezi
import SpeziFirestore
import UserNotifications


/// Tracks notification-related events and persists them to firebase
final class NotificationTracking: Module, @unchecked Sendable {
    @Application(\.logger)
    private var logger
    
    @Dependency(FirebaseConfiguration.self)
    private var firebaseConfiguration
    
    func trackDidOpen(_ response: UNNotificationResponse) {
        let event = TrackedNotificationEvent(
            timestamp: .now,
            timeZone: TimeZone.current.identifier,
            event: .opened,
            notificationId: response.notification.request.identifier
        )
        Task {
            do {
                let doc = try await firebaseConfiguration.userDocumentReference
                    .collection("notificationTracking")
                    .document(UUID().uuidString)
                try await doc.setData(from: event)
            } catch {
                logger.error("Error: \(error)")
            }
        }
    }
}


extension NotificationTracking {
    private struct TrackedNotificationEvent: Encodable {
        enum Event: String, Encodable {
            case opened
        }
        
        let timestamp: Date
        let timeZone: String
        let event: Event
        let notificationId: String
    }
}
