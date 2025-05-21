//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

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
final class MyHeartCountsDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: MyHeartCountsStandard()) {
            DeferredConfigLoading.initialAppLaunchConfig
            HealthKit {
                RequestReadAccess(quantity: [.heartRate, .stepCount, .bodyMass, .height, .bodyMassIndex])
                RequestWriteAccess(quantity: [.heartRate, .stepCount])
            }
            Scheduler()
            Notifications()
            BulkHealthExporter()
            HistoricalHealthSamplesExportManager()
            StudyDefinitionLoader.shared
        }
    }
    
    override func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? // swiftlint:disable:this discouraged_optional_collection
    ) -> Bool {
        let prefs = LocalPreferencesStore.standard
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


extension ModuleBuilder {
    // periphery:ignore - implicitly called
    static func buildExpression(_ modules: some Sequence<any Module>) -> [any Module] {
        Array(modules)
    }
}
