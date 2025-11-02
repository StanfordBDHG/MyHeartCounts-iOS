//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable attributes

import OSLog
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
    private let title: LocalizedStringResource = "HealthKit Access"
    
    @Environment(HealthKit.self) private var healthKit
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(StudyBundleLoader.self) private var studyLoader
    @AccountFeatureFlagQuery(.enableHealthRecords) private var enableHealthRecords
    
    @State private var viewState: ViewState = .idle
    @State private var isShowingLearnMoreText = false
    
    var body: some View {
        OnboardingPage(symbol: .heartTextSquare, title: title, description: "HEALTHKIT_PERMISSIONS_SUBTITLE") {
            EmptyView()
        } footer: {
            OnboardingActionsView(
                primaryTitle: "Grant Access",
                primaryViewState: $viewState,
                primaryAction: {
                    await grantAccess()
                },
                secondaryTitle: "Learn More",
                secondaryAction: {
                    isShowingLearnMoreText.toggle()
                }
            )
        }
        .sheet(isPresented: $isShowingLearnMoreText) {
            OnboardingLearnMore(
                title: title,
                learnMoreText: "HEALTHKIT_PERMISSIONS_DESCRIPTION"
            )
        }
        .navigationBarBackButtonHidden(viewState != .idle)
    }
    
    
    private func grantAccess() async {
        guard let studyBundle = try? studyLoader.studyBundle?.get() else {
            // guaranteed to be non-nil if we end up in this view
            return
        }
        do {
            // HealthKit is not available in the preview simulator.
            if ProcessInfo.processInfo.isPreviewSimulator {
                try await _Concurrency.Task.sleep(for: .seconds(5))
            } else {
                let accessReqs = MyHeartCountsStandard.baselineHealthAccessReqs
                    .merging(with: .init(read: studyBundle.studyDefinition.allCollectedHealthData))
                try await healthKit.askForAuthorization(for: accessReqs)
            }
        } catch {
            logger.error("Could not request HealthKit permissions: \(error)")
        }
        // The `enableHealthRecords` condition depends on the Account being present, which is not injected into the overall `OnboardingFlow` view,
        // meaning that we can't decide this in there. Instead, we decide in here how to proceed.
        if enableHealthRecords {
            path.append {
                HealthRecords()
                    .onboardingStep(.healthRecords)
                    .injectingSpezi()
            }
        } else {
            path.nextStep()
        }
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


extension ManagedNavigationStack.Path {
    func append(@ViewBuilder view: () -> some View) {
        self.append(customView: view())
    }
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
