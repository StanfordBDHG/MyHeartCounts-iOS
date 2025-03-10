//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziAccount
import SpeziFirebaseAccount
import SpeziHealthKit
import SpeziNotifications
import SpeziOnboarding
import SpeziStudy
import SwiftUI


/// Displays a multi-step onboarding flow for the My Heart Counts iOS app
///
/// - Note: This is the general app onboarding flow, **not** the study-specific onboarding
struct AppOnboardingFlow: View {
    @Environment(StudyManager.self)
    private var mhc
    @Environment(HealthKit.self)
    private var healthKitDataSource
    
    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(\.notificationSettings)
    private var notificationSettings
    
    @AppStorage(StorageKeys.onboardingFlowComplete)
    private var completedOnboardingFlow = false
    
    @State private var localNotificationAuthorization = false
    @State private var data = ScreeningDataCollection()
    
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $completedOnboardingFlow) {
            // TOOD include smth like this?
//            BetaDisclaimer()
            Welcome()
            
            SinglePageScreening(title: "Screening", subtitle: "Before we can continue,\nwe need to learn a little about you") {
                AgeAtLeast(minAge: 18)
                IsFromRegion(allowedRegion: .unitedStates)
                SpeaksLanguage(allowedLanguage: .init(identifier: "en_US"))
                CanPerformPhysicalActivity()
            }
            
            if !FeatureFlags.disableFirebase {
                AccountOnboarding()
            }
            #if !(targetEnvironment(simulator) && (arch(i386) || arch(x86_64)))
            Consent()
            #endif
            
            if HKHealthStore.isHealthDataAvailable() {
                // IDEA instead of having this in an if, we should probably have a full-screen "you can't participate" thing if the user doesn't have HealthKit?
                HealthKitPermissions()
            }
            
            if !localNotificationAuthorization {
                NotificationPermissions()
            }
            
            FinalEnrollmentStep()
        }
        .environment(data)
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
