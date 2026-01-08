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
import SpeziHealthKit
import SpeziOnboarding
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct HealthRecords: View {
    private let title: LocalizedStringResource = "Health Records"
    
    @Environment(MyHeartCountsStandard.self) private var standard
    @Environment(HealthKit.self) private var healthKit
    @Environment(StudyBundleLoader.self) private var studyLoader
    @Environment(ManagedNavigationStack.Path.self) private var path
    
    @State private var viewState: ViewState = .idle
    @State private var isShowingLearnMoreText = false
    
    var body: some View {
        let symbol: SFSymbol = if #available(iOS 18.1, *) {
            .waveformPathEcgTextPage
        } else {
            .heartTextSquare
        }
        OnboardingPage(symbol: symbol, title: title, description: "HEALTH_RECORDS_PERMISSIONS_SUBTITLE") {
            EmptyView()
        } footer: {
            OnboardingActionsView(
                primaryTitle: "Review Permissions",
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
                learnMoreText: "HEALTH_RECORDS_PERMISSIONS_DESCRIPTION"
            )
        }
        .navigationBarBackButtonHidden(viewState != .idle)
    }
    
    
    private func grantAccess() async {
        guard let studyBundle = try? studyLoader.studyBundle?.get() else {
            return
        }
        do {
            let clinicalTypes = studyBundle.studyDefinition.allCollectedHealthData.filter {
                $0.hkSampleType is HKClinicalType
            }
            try await healthKit.askForAuthorization(for: .init(read: clinicalTypes))
        } catch {
            logger.error("Error requesting access to health records: \(error)")
        }
        path.nextStep()
    }
}


extension MyHeartCountsStandard {
    static let allRecordTypes: [SampleType<HKClinicalRecord>] = [
        .allergyRecord,
        .clinicalNoteRecord,
        .conditionRecord,
        .immunizationRecord,
        .labResultRecord,
        .medicationRecord,
        .procedureRecord,
        .vitalSignRecord,
        .coverageRecord
    ]
}
