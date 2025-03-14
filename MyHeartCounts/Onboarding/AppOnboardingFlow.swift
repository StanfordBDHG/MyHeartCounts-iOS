//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(APISupport)
import Spezi
@_spi(TestingSupport)
import SpeziAccount
import SpeziFirebaseAccount
import SpeziHealthKit
import SpeziNotifications
import SpeziOnboarding
import SpeziStudy
import SpeziViews
import SwiftUI


struct OnboardingSheet: View {
    @Binding var didCompleteOnboarding: Bool
    
    var body: some View {
        if !didCompleteOnboarding {
            Color.clear.frame(height: 0)
                .sheet(isPresented: !$didCompleteOnboarding) {
                    AppOnboardingFlow(didCompleteOnboarding: $didCompleteOnboarding)
                }
        }
    }
}

/// Displays a multi-step onboarding flow for the My Heart Counts iOS app
///
/// - Note: This is the general app onboarding flow, **not** the study-specific onboarding
struct AppOnboardingFlow: View {
    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(\.notificationSettings)
    private var notificationSettings
    
    @Binding var didCompleteOnboarding: Bool
    
    @State private var screeningData = ScreeningDataCollection()
    @State private var localNotificationAuthorization = false
    
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $didCompleteOnboarding) {
            Welcome()
            SinglePageScreening(
                title: "Screening",
                subtitle: "Before we can continue,\nwe need to learn a little about you"
            ) {
                AgeAtLeast(minAge: 18)
                IsFromRegion(allowedRegions: [.unitedStates])
                SpeaksLanguage(allowedLanguage: .init(identifier: "en_US"))
                CanPerformPhysicalActivity()
            }
            if !FeatureFlags.disableFirebase {
                AccountOnboarding()
                    .injectingSpezi()
                    .navigationBarBackButtonHidden()
            }
            #if !(targetEnvironment(simulator) && (arch(i386) || arch(x86_64)))
            Consent()
                .injectingSpezi()
            #endif
            if HKHealthStore.isHealthDataAvailable() {
                // IDEA instead of having this in an if, we should probably have a full-screen "you can't participate" thing if the user doesn't have HealthKit?
                HealthKitPermissions()
                    .injectingSpezi()
            }
            if !localNotificationAuthorization {
                NotificationPermissions()
                    .injectingSpezi()
            }
            FinalEnrollmentStep()
                .injectingSpezi()
        }
        .environment(screeningData)
        .interactiveDismissDisabled(!didCompleteOnboarding)
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
