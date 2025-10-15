//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import Spezi
@_spi(TestingSupport)
import SpeziAccount
import SpeziFirebaseAccount
import SpeziHealthKit
import SpeziLLMLocal
import SpeziLLMLocalDownload
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
private struct AppOnboardingFlow: View {
    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(\.notificationSettings)
    private var notificationSettings
    
    @Binding var didCompleteOnboarding: Bool
    
    @State private var onboardingData = OnboardingDataCollection()
    @State private var localNotificationAuthorization = false
    
    
    var body: some View {
        ManagedNavigationStack(didComplete: $didCompleteOnboarding) { // swiftlint:disable:this closure_body_length
            Welcome()
                .onboardingStep(.welcome)
            EligibilityScreening()
                .onboardingStep(.eligibility)
            if !FeatureFlags.disableFirebase {
                AccountOnboarding()
                    .injectingSpezi()
                    .navigationBarBackButtonHidden()
                    .onboardingStep(.login)
            }
            OnboardingDisclaimerStep(
                icon: .textPageBadgeMagnifyingglass,
                title: "ONBOARDING_DISCLAIMER_1_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_1_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_1_LEARN_MORE_TEXT"
            )
                .onboardingStep(.disclaimer1)
                .injectingSpezi()
            OnboardingDisclaimerStep(
                icon: .figureWalkMotion,
                title: "ONBOARDING_DISCLAIMER_2_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_2_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_2_LEARN_MORE_TEXT"
            )
                .onboardingStep(.disclaimer2)
                .injectingSpezi()
            OnboardingDisclaimerStep(
                icon: .lockSquareStack,
                title: "ONBOARDING_DISCLAIMER_3_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_3_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_3_LEARN_MORE_TEXT"
            )
                .onboardingStep(.disclaimer3)
                .injectingSpezi()
            OnboardingDisclaimerStep(
                icon: .documentOnClipboard,
                title: "ONBOARDING_DISCLAIMER_4_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_4_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_4_LEARN_MORE_TEXT"
            )
                .onboardingStep(.disclaimer4)
                .injectingSpezi()
            ComprehensionScreening()
                .onboardingStep(.comprehension)
                .injectingSpezi()
            #if !(targetEnvironment(simulator) && (arch(i386) || arch(x86_64)))
            Consent()
                .onboardingStep(.consent)
                .injectingSpezi()
                .navigationStepIdentifier("Consent")
            #endif
            if HKHealthStore.isHealthDataAvailable() {
                // IDEA instead of having this in an if, we should probably have a full-screen "you can't participate" thing if the user doesn't have HealthKit?
                HealthKitPermissions()
                    .onboardingStep(.healthAccess)
                    .injectingSpezi()
            }
            WorkoutPreferenceSetting()
                .onboardingStep(.workoutPreference)
                .injectingSpezi()
            if !localNotificationAuthorization {
                NotificationPermissions()
                    .onboardingStep(.notifications)
                    .injectingSpezi()
            }
            DemographicsStep()
                .onboardingStep(.demographics)
                .injectingSpezi()
            if FeatureFlags.downloadLLM {
                LLMLocalDownloadStep()
                    .onboardingStep(.LLMDownload)
                    .injectingSpezi()
            }
            FinalEnrollmentStep()
                .onboardingStep(.finalStep)
                .injectingSpezi()
        }
        .environment(\.isInOnboardingFlow, true)
        .environment(onboardingData)
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


private struct LLMLocalDownloadStep: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    var body: some View {
        LLMLocalDownloadView(
            model: .llama3_2_1B_4bit,
            downloadDescription: "The Llama3.3 1B model will be downloaded to enable on-device AI features."
        ) {
            // This closure runs after the download is complete and the user taps the 'Next' button
            path.nextStep()
        }
    }
}


extension OnboardingStep {
    static let welcome = Self(rawValue: "welcome")
    static let eligibility = Self(rawValue: "eligibility")
    static let login = Self(rawValue: "login")
    static let disclaimer1 = Self(rawValue: "disclaimer1")
    static let disclaimer2 = Self(rawValue: "disclaimer2")
    static let disclaimer3 = Self(rawValue: "disclaimer3")
    static let disclaimer4 = Self(rawValue: "disclaimer4")
    static let comprehension = Self(rawValue: "comprehension")
    static let consent = Self(rawValue: "consent")
    static let healthAccess = Self(rawValue: "healthAccess")
    static let workoutPreference = Self(rawValue: "workoutPreference")
    static let notifications = Self(rawValue: "notifications")
    static let demographics = Self(rawValue: "demographics")
    static let LLMDownload = Self(rawValue: "LLMDownload")
    static let finalStep = Self(rawValue: "finalStep")
}
