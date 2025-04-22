//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable attributes

import Spezi
import SpeziFirebaseConfiguration
import SpeziHealthKit
import SpeziHealthKitBulkExport
import SpeziNotifications
import SpeziOnboarding
import SpeziScheduler
import SpeziStudy
import SwiftUI
import UserNotifications


@Observable
class MyHeartCountsDelegate: SpeziAppDelegate { // swiftlint:disable:this file_types_order
    override var configuration: Configuration {
        Configuration(standard: MyHeartCountsStandard()) {
            DeferredConfigLoading.initialAppLaunchConfig
            HealthKit()
            Scheduler()
            Notifications()
            ConfigureFirebaseAppAccessor()
            BulkHealthExporter()
            HistoricalHealthSamplesExportManager()
        }
    }
    
    override func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? // swiftlint:disable:this discouraged_optional_collection
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        let prefs = LocalPreferencesStore.shared
        if FeatureFlags.showOnboarding {
            prefs[.onboardingFlowComplete] = false
            prefs[.lastUsedFirebaseConfig] = nil
        }
        if FeatureFlags.skipOnboarding {
            prefs[.onboardingFlowComplete] = true
        }
        return super.application(application, willFinishLaunchingWithOptions: launchOptions)
    }
}


extension MyHeartCountsDelegate: UNUserNotificationCenterDelegate { // swiftlint:disable:this file_types_order
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.badge, .banner, .list, .sound]
    }
}


extension ModuleBuilder { // swiftlint:disable:this file_types_order
    // periphery:ignore - implicitly called
    static func buildExpression(_ modules: some Sequence<any Module>) -> [any Module] {
        Array(modules)
    }
}


@Observable
final class ConfigureFirebaseAppAccessor: Module, DefaultInitializable, EnvironmentAccessible {
    @ObservationIgnored @Dependency(ConfigureFirebaseApp.self)
    var configureFirebase: ConfigureFirebaseApp?
}
