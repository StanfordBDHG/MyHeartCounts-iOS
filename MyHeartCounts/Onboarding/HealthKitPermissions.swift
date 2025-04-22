//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziHealthKit
import SpeziOnboarding
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct HealthKitPermissions: View {
    @Environment(HealthKit.self)
    private var healthKit
    @Environment(ManagedNavigationStack.Path.self)
    private var onboardingPath
    
    @State private var healthKitProcessing = false
    
    var body: some View {
        OnboardingView {
            VStack {
                OnboardingTitleView(
                    title: "HealthKit Access",
                    subtitle: "HEALTHKIT_PERMISSIONS_SUBTITLE"
                )
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 150))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                Text("HEALTHKIT_PERMISSIONS_DESCRIPTION")
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                Spacer()
            }
        } footer: {
            OnboardingActionsView("Grant Access") {
                do {
                    healthKitProcessing = true
                    // HealthKit is not available in the preview simulator.
                    if ProcessInfo.processInfo.isPreviewSimulator {
                        try await _Concurrency.Task.sleep(for: .seconds(5))
                    } else {
                        try await healthKit.askForAuthorization(for: .init(read: mockMHCStudy.allCollectedHealthData))
                    }
                } catch {
                    print("Could not request HealthKit permissions.")
                }
                healthKitProcessing = false
                onboardingPath.nextStep()
            }
        }
        .navigationBarBackButtonHidden(healthKitProcessing)
        // Small fix as otherwise "Login" or "Sign up" is still shown in the nav bar
        .navigationTitle(Text(verbatim: ""))
    }
}


#if DEBUG
#Preview {
    ManagedNavigationStack {
        HealthKitPermissions()
    }
    .previewWith(standard: MyHeartCountsStandard()) {
        HealthKit()
    }
}
#endif
