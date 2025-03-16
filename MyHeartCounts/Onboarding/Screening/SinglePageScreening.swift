//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziFoundation
import SpeziOnboarding
import SpeziViews
import SwiftUI


/// A Screening View, that collects all data on a single page.
///
/// Intended to be used in an `OnboardingStack`.
struct SinglePageScreening: View {
    @Environment(OnboardingNavigationPath.self)
    private var path
    @Environment(ScreeningDataCollection.self)
    private var screeningData
    
    private let title: LocalizedStringResource
    private let subtitle: LocalizedStringResource
    private let components: [any ScreeningComponent]
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: title, subtitle: subtitle)
        } contentView: {
            Form {
                ForEach(0..<components.endIndex, id: \.self) { idx in
                    let component = components[idx]
                    Section {
                        component.intoAnyView()
                    } header: {
                        Text(component.title)
                    }
                }
                Section {
                    OnboardingActionsView("Continue") {
                        await evaluateEligibilityAndProceed()
                    }
                    .disabled(!screeningData.allPropertiesAreNonnil)
                    .listRowInsets(.zero)
                    // ISSUE(@lukas) can we somehow make it so that the scroll view fills the entire screen? ie, all the way to the bottom?
                }
            }
        } actionView: {
            EmptyView()
        }
        .disablePadding([.horizontal, .bottom])
        .makeBackgroundMatchFormBackground()
    }
    
    init(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        @ArrayBuilder<any ScreeningComponent> components: () -> [any ScreeningComponent]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.components = components()
    }
    
    private func evaluateEligibilityAndProceed() async {
        let isEligible = components.allSatisfy { $0.evaluate(screeningData) }
        if isEligible {
            guard let region = screeningData.region else {
                // IDEA(@lukas) maybe show an alert? (we will never end up in here)
                return
            }
            _ = await Task.detached {
                // load the firebase modules into Spezi, and give it a couple seconds to fully configure everything
                await Spezi.loadFirebase(for: region)
                try await Task.sleep(for: .seconds(4))
            }.result
            path.nextStep()
        } else {
            path.append(customView: NotEligibleView())
        }
    }
}
