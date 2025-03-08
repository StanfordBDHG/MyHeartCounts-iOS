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

// TODO(@lukas) it's a btit absurd that, if the user was logged in before deleting and reinstallng the app, we have an onboarding
// step showing the account (incl the user's first&last name) and offering a big beautify stay logged in button, only to then in the next
// step (the consent) ask the user to please manually enter their first&last name...

/// Displays an multi-step onboarding flow for the My Heart Counts iOS app
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
            
            
//            AgeCheck(requiredMinAgeInYears: 18)
//            LanguageCheck(language: Locale.Language(identifier: "en"))
//            RegionCheck(allowedRegions: [.unitedStates, .unitedKingdom])
//            BooleanScreeningStep(
//                title: "Activity",
//                question: "Are you able to perform physical activity?",
//                explanation: "As part of the My Heart Counts study, participants will be required to perform [moderate?] amounts of physical activity"
//            )
            EligibilityScreening()
            
            if !FeatureFlags.disableFirebase {
                AccountOnboarding()
            }
            #if !(targetEnvironment(simulator) && (arch(i386) || arch(x86_64)))
            Consent()
            #endif
            
            if HKHealthStore.isHealthDataAvailable() {
                // TODO instead of having this in an if, we should probably have a full-screen "you can't participate" thing if the user doesn't have HealthKit?
                HealthKitPermissions()
            }
            
            if !localNotificationAuthorization {
                NotificationPermissions()
            }
            
            finalWelcomeStep
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
    
    
    @ViewBuilder private var finalWelcomeStep: some View {
        withOnboardingStackPath { path in
            OnboardingView {
                OnboardingTitleView(title: "My Heart Counts")
            } contentView: {
                Text("You're all set.\n\nGreat to have you on board!")
            } actionView: {
                OnboardingActionsView("Complete") {
                    try await mhc.enroll(in: mockMHCStudy) // TODO have this show a spinner in the button? in case this takes a little longer?
                    path.nextStep()
                }
            }
        }
    }
}
