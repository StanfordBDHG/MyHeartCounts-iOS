//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseMessaging
import Foundation
import Spezi
import SpeziAccount
import SpeziNotifications


@Observable
@MainActor
final class NotificationsManager: NSObject, Module, EnvironmentAccessible, Sendable {
    struct RemoteNotificationsToken: Sendable {
        let apns: Data?
        let fcm: String?
    }
    
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger)
    private var logger
    @ObservationIgnored @Dependency(Notifications.self)
    private var notifications
    @ObservationIgnored @Application(\.registerRemoteNotifications)
    private var registerRemoteNotifications
    @ObservationIgnored @Dependency(Account.self)
    private var account: Account?
    // swiftlint:enable attributes
    
    private(set) var isAuthorized = false
    
    private(set) var remoteNotificationsToken: RemoteNotificationsToken?
    
    
    func configure() {
        guard LocalPreferencesStore.standard[.onboardingFlowComplete] else {
            return
        }
        Messaging.messaging().delegate = self
        Task {
            try await setup()
        }
    }
    
    func requestNotificationPermissions() async throws {
        try await notifications.requestNotificationAuthorization(options: [.alert, .badge, .sound, .providesAppNotificationSettings])
        try await _setup(requestPermissionsIfNotDetermined: false)
    }
    
    func setup() async throws {
        try await _setup(requestPermissionsIfNotDetermined: true)
    }
    
    private func _setup(requestPermissionsIfNotDetermined: Bool) async throws {
        let settings = await notifications.notificationSettings()
        logger.notice("in setup. settings.authStatus: \(settings.authorizationStatus.description)")
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
            #if !TEST
            logger.notice("Will fetch token")
            do {
                let messaging = Messaging.messaging()
                let apnsToken = try await registerRemoteNotifications()
                logger.notice("Did fetch token")
                logger.notice("got remote notifications token: \(apnsToken)")
                messaging.apnsToken = apnsToken
                let fcmToken = try? await messaging.token()
                self.remoteNotificationsToken = .init(apns: apnsToken, fcm: fcmToken)
            } catch {
                logger.error("Unable to register for remote notifications: \(error)")
            }
            #endif
        case .denied:
            isAuthorized = false
        case .notDetermined:
            if requestPermissionsIfNotDetermined {
                // shouldn't really end up here since we request notification permissions as part of the onboarding,
                // but we'll simply trigger it again, just in case.
                try await requestNotificationPermissions()
            }
        @unknown default:
            isAuthorized = false
        }
    }
}


extension NotificationsManager: NotificationHandler {
    func handleNotificationAction(_ response: UNNotificationResponse) async {
        logger.notice("\(#function) \(response)")
    }
    
    func receiveIncomingNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions? {
        logger.notice("\(#function) \(notification)")
        return [.badge, .badge, .list, .sound]
    }
    
    func receiveRemoteNotification(_ remoteNotification: [AnyHashable: Any]) async -> BackgroundFetchResult {
        logger.notice("\(#function) \(remoteNotification)")
        return .noData
    }
}


extension NotificationsManager: NotificationTokenHandler {
    func receiveUpdatedDeviceToken(_ deviceToken: Data) {
        logger.notice("\(#function) \(deviceToken)")
    }
}


extension NotificationsManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let messagingDesc = String(reflecting: messaging)
        Task {
            await self.logger.notice("\(#function) \(messagingDesc) \(fcmToken ?? "<nil>")")
        }
    }
}
