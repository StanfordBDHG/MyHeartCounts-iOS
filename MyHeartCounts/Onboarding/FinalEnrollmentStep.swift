//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
//@_spi(APISupport)
import Spezi
import SpeziOnboarding
import SpeziStudy
import SwiftUI


struct FinalEnrollmentStep: View {
    @Environment(OnboardingNavigationPath.self)
    private var path
    @AppStorage(StorageKeys.onboardingFlowComplete)
    private var completedOnboardingFlow = false
    @Environment(ScreeningDataCollection.self)
    private var screeningData
    @Environment(StudyManager.self)
    private var studyManager
//    @Environment(Spezi.self)
//    private var spezi
    @Environment(FirebaseLoader.self)
    private var firebaseLoader
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "My Heart Counts")
        } contentView: {
            Text("You're all set.\n\nGreat to have you on board!")
        } actionView: {
            OnboardingActionsView("Complete") {
//                try await enroll()
                path.nextStep()
//                firebaseLoader.loadFirebase(for: screeningData.region!)
                try await studyManager.enroll(in: mockMHCStudy)
            }
        }
    }
    
    
//    private func enroll() async throws {
////        switch screeningData.region {
////        case .unitedStates:
////        }
//        fatalError() // TOSO
//        try await studyManager.enroll(in: mockMHCStudy)
//    }
}
