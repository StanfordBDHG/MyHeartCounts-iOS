//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

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
            EligibilityScreening()
            if !FeatureFlags.disableFirebase {
                AccountOnboarding()
                    .injectingSpezi()
                    .navigationBarBackButtonHidden()
            }
            OnboardingDisclaimerStep(
                title: "ONBOARDING_DISCLAIMER_1_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_1_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_1_LEARN_MORE_TEXT"
            )
            OnboardingDisclaimerStep(
                title: "ONBOARDING_DISCLAIMER_2_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_2_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_2_LEARN_MORE_TEXT"
            )
            OnboardingDisclaimerStep(
                title: "ONBOARDING_DISCLAIMER_3_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_3_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_3_LEARN_MORE_TEXT"
            )
            OnboardingDisclaimerStep(
                title: "ONBOARDING_DISCLAIMER_4_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_4_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_4_LEARN_MORE_TEXT"
            )
            ComprehensionScreening()
            #if !(targetEnvironment(simulator) && (arch(i386) || arch(x86_64)))
            Consent()
                .injectingSpezi()
                .navigationStepIdentifier("Consent")
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
            DemographicsStep()
                .injectingSpezi()
            FinalEnrollmentStep()
                .injectingSpezi()
        }
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


private struct DemographicsStep: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    var body: some View {
        DemographicsForm {
            OnboardingActionsView("Continue") {
                path.nextStep()
            }
            .listRowInsets(.zero)
        }
    }
}
