//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziAccount
import SpeziFirebaseAccount
import SpeziHealthKit
import SpeziNotifications
import SpeziOnboarding
import SwiftUI

// TODO(@lukas) it's a btit absurd that, if the user was logged in before deleting and reinstallng the app, we have an onboarding
// step showing the account (incl the user's first&last name) and offering a big beautify stay logged in button, only to then in the next
// step (the consent) ask the user to please manually enter their first&last name...

/// Displays an multi-step onboarding flow for the My Heart Counts iOS app
///
/// - Note: This is the general app onboarding flow, **not** the study-specific onboarding
struct AppOnboardingFlow: View {
    @Environment(HealthKit.self) private var healthKitDataSource
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.notificationSettings) private var notificationSettings
    
    @AppStorage(StorageKeys.onboardingFlowComplete) private var completedOnboardingFlow = false
    
    @State private var localNotificationAuthorization = false
    
    @MainActor private var healthKitAuthorization: Bool {
        // As HealthKit not available in preview simulator
        if ProcessInfo.processInfo.isPreviewSimulator {
            return false
        }
        return healthKitDataSource.isFullyAuthorized
    }
    
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $completedOnboardingFlow) {
            Welcome()
//                .background(Color.orange)
//            InterestingModules()
            
            AppUsageRestrictions()
//                .background(Color.green)
            
            if !FeatureFlags.disableFirebase {
                AccountOnboarding()
            }
            
            #if !(targetEnvironment(simulator) && (arch(i386) || arch(x86_64)))
                Consent()
            #endif
            
            if HKHealthStore.isHealthDataAvailable() && !healthKitAuthorization {
                HealthKitPermissions()
            }
            
            if !localNotificationAuthorization {
                NotificationPermissions()
            }
        }
        .interactiveDismissDisabled(!completedOnboardingFlow)
        .onChange(of: scenePhase, initial: true) {
            guard case .active = scenePhase else {
                return
            }
            Task {
                localNotificationAuthorization = await notificationSettings().authorizationStatus == .authorized
            }
        }
    }
}


//#if DEBUG
//#Preview {
//    AppOnboardingFlow()
//        .previewWith(standard: MyHeartCountsStandard()) {
//            AccountConfiguration(service: InMemoryAccountService())
//            HealthKit {
//                // TODO do we need anything in here, this early in the lifecycle?
//            }
//            MyHeartCountsScheduler()
//        }
//}
//#endif
