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
    
    @Environment(StudyBundleLoader.self)
    private var studyLoader
    
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
                guard let studyBundle = try? studyLoader.studyBundle?.get() else {
                    // guaranteed to be non-nil if we end up in this view
                    return
                }
                do {
                    healthKitProcessing = true
                    // HealthKit is not available in the preview simulator.
                    if ProcessInfo.processInfo.isPreviewSimulator {
                        try await _Concurrency.Task.sleep(for: .seconds(5))
                    } else {
                        let accessReqs = MyHeartCountsStandard.baselineHealthAccessReqs
                            .merging(with: .init(read: studyBundle.studyDefinition.allCollectedHealthData))
                        try await healthKit.askForAuthorization(for: accessReqs)
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


extension MyHeartCountsStandard {
    static let baselineHealthAccessReqs = HealthKit.DataAccessRequirements(
        read: [
            HealthKitCharacteristic.activityMoveMode.hkType,
            HealthKitCharacteristic.biologicalSex.hkType,
            HealthKitCharacteristic.bloodType.hkType,
            HealthKitCharacteristic.dateOfBirth.hkType,
            HealthKitCharacteristic.fitzpatrickSkinType.hkType,
            HealthKitCharacteristic.wheelchairUse.hkType
        ],
        write: ([
            SampleType.workout,
            SampleType.height, SampleType.bodyMass, SampleType.bodyMassIndex,
            SampleType.bloodGlucose, SampleType.bloodPressure
        ] as [any AnySampleType]).map { $0.hkSampleType }
    )
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
