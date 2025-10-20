//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import Spezi
import SpeziAccount
import SpeziHealthKit
import SpeziOnboarding
import SpeziStudy
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct HealthKitPermissions: View {
    private var title = LocalizedStringResource("HealthKit Access")
    
    @Environment(HealthKit.self)
    private var healthKit
    
    @Environment(ManagedNavigationStack.Path.self)
    private var onboardingPath
    
    @Environment(StudyBundleLoader.self)
    private var studyLoader
    
    @State private var healthKitProcessing = false
    @State private var isShowingLearnMoreText = false
    
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    OnboardingHeader(
                        systemSymbol: .heartTextSquare,
                        title: title,
                        description: "HEALTHKIT_PERMISSIONS_SUBTITLE"
                    )
                }
                .padding(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize)
            Spacer(minLength: 8)
                .border(Color.blue, width: 1)
            OnboardingActionsView(
                primaryTitle: "Grant Access",
                primaryAction: {
                    await grantAccess()
                },
                secondaryTitle: "Learn More",
                secondaryAction: {
                    isShowingLearnMoreText.toggle()
                }
            )
            .padding(.horizontal)
        }
        .sheet(isPresented: $isShowingLearnMoreText) {
            OnboardingLearnMore(
                title: title,
                learnMoreText: "HEALTHKIT_PERMISSIONS_DESCRIPTION"
            )
        }
        .navigationTitle(Text(verbatim: ""))
        .toolbar(.visible)
        .navigationBarBackButtonHidden(healthKitProcessing)
    }
    
    
    private func grantAccess() async {
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


extension MyHeartCountsStandard {
    static let baselineHealthAccessReqs = HealthKit.DataAccessRequirements(
        read: [
            HealthKitCharacteristic.activityMoveMode.hkType,
            HealthKitCharacteristic.biologicalSex.hkType,
            HealthKitCharacteristic.bloodType.hkType,
            HealthKitCharacteristic.dateOfBirth.hkType,
            HealthKitCharacteristic.fitzpatrickSkinType.hkType,
            HealthKitCharacteristic.wheelchairUse.hkType
        ] + HKElectrocardiogram.correlatedSymptomTypes.map(\.hkSampleType),
        write: ([
            SampleType.workout,
            SampleType.height, SampleType.bodyMass, SampleType.bodyMassIndex,
            SampleType.bloodGlucose, SampleType.bloodPressure
        ] as [any AnySampleType]).map { $0.hkSampleType }
    )
}


#Preview {
    ManagedNavigationStack {
        HealthKitPermissions()
    }
    .environment(StudyBundleLoader.shared)
    .previewWith(standard: MyHeartCountsStandard()) {
        HealthKit()
        MyHeartCounts.previewModels
    }
}
