//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziHealthKit
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct DemographicsStep: View {
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


#Preview {
    ManagedNavigationStack {
        DemographicsStep()
    }
        .previewWith(standard: MyHeartCountsStandard()) {
            HealthKit()
            MyHeartCountsStandard.previewModels
        }
}
