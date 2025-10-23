//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable discouraged_optional_collection

import OSLog
import Spezi
import SpeziFirebaseConfiguration
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitBulkExport
import SpeziNotifications
import SpeziOnboarding
import SpeziScheduler
import SpeziSensorKit
import SpeziStudy
import SwiftUI
import UserNotifications


@Observable
final class MyHeartCountsDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        if let selector = FeatureFlags.overrideFirebaseConfig {
            LocalPreferencesStore.standard[.lastUsedFirebaseConfig] = selector
        }
        return Configuration(standard: MyHeartCountsStandard()) {
            FirebaseConfiguration()
            SetupTestEnvironment()
            DeferredConfigLoading.initialAppLaunchConfig
            HealthKit()
            Scheduler()
            Notifications()
            BulkHealthExporter()
            HistoricalHealthSamplesExportManager()
            StudyBundleLoader.shared
            WatchConnection()
            TimedWalkingTest()
            FeedbackManager()
            SensorKit()
            SensorKitDataFetcher()
            LocalNotifications()
            Lifecycle()
            AppRefresh()
            MHCBackgroundTasks()
            MotionDataFetcher()
        }
    }
    
    override func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        logger.notice("\(#function)")
        return super.application(application, willFinishLaunchingWithOptions: launchOptions)
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        logger.notice("\(#function)")
        return true
    }
}


extension ModuleBuilder {
    // periphery:ignore - implicitly called
    static func buildExpression(_ modules: some Sequence<any Module>) -> [any Module] {
        Array(modules)
    }
}
