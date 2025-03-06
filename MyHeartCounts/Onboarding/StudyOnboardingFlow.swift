//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI
import SpeziStudy
import SpeziOnboarding
import SpeziNotifications


struct StudyOnboardingFlow: View {
    @Environment(\.registerRemoteNotifications) private var registerRemoteNotifications
    
    let study: StudyDefinition
    
    @State private var didComplete = false // TODO do we need this?
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $didComplete) {
            initialPage
            studyOverviewPage
            if !study.healthDataCollectionComponents.isEmpty {
                healthAccessPermissions
            }
            finalStep
        }
    }
    
    
    @ViewBuilder private var initialPage: some View {
        withOnboardingStackPath { path in
            OnboardingView {
                Text("Welcome to\n\(study.metadata.title)")
                    .background(Color.green)
            } contentView: {
                Text("This is the content view")
                    .background(Color.red)
            } actionView: {
                OnboardingActionsView("Get Started") {
                    path.nextStep()
                }
            }
        }
    }
    
    
    @ViewBuilder private var studyOverviewPage: some View {
        withOnboardingStackPath { path in
            OnboardingView {
                OnboardingTitleView(title: study.metadata.title)
            } contentView: {
                Text("TODO come up w/ smth to put here!!!")
            } actionView: {
                OnboardingActionsView("Continue") {
                    path.nextStep()
                }
            }
        }
    }
    
    
    @ViewBuilder private var healthAccessPermissions: some View {
        withOnboardingStackPath { path in
//            OnboardingView
            // TODO
        }
    }
    
    
    @ViewBuilder private var notificationsPermissions: some View {
        withOnboardingStackPath { path in
            OnboardingView {
                OnboardingTitleView(title: "Notifications")
            } contentView: {
            } actionView: {
                OnboardingActionsView(
                    primaryText: "Allow Push Notifications",
                    primaryAction: {
                        defer {
                            path.nextStep()
                        }
                        try await registerRemoteNotifications()
                    },
                    secondaryText: "Skip for now"
                ) {
                    path.nextStep()
                }
            }
        }
    }
    
    
    @ViewBuilder private var finalStep: some View {
        withOnboardingStackPath { path in
            OnboardingView {
                OnboardingTitleView(
                    title: study.metadata.title
                )
            } contentView: {
                Text("You're all set and ready to go 🚀")
            } actionView: {
                OnboardingActionsView("Continue") {
                    path.nextStep()
                }
            }
        }
    }
}
