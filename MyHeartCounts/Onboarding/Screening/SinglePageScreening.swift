//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziFirebaseConfiguration
import SpeziFoundation
import SpeziOnboarding
import SpeziViews
import SwiftUI


/// A Screening View, that collects all data on a single page.
///
/// Intended to be used in an `OnboardingStack`.
struct SinglePageScreening: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    @Environment(ScreeningDataCollection.self)
    private var screeningData
    @Environment(StudyDefinitionLoader.self)
    private var studyLoader
    
    private let title: LocalizedStringResource
    private let subtitle: LocalizedStringResource
    private let components: [any ScreeningComponent]
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: title, subtitle: subtitle)
        } content: {
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
                    AsyncButton(state: $viewState) {
                        await evaluateEligibilityAndProceed()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdvanceToNextStep)
                    .listRowInsets(.zero)
                    // ISSUE(@lukas) can we somehow make it so that the scroll view fills the entire screen? ie, all the way to the bottom?
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // IDEA: have this button always be active, but if the screening hasn't been filled out yet entirely,
                    // it is grey (to appear disabled), but tapping it simply scrolls down to the first-non-completed screennig section?
                    AsyncButton("Continue", state: $viewState) {
                        await evaluateEligibilityAndProceed()
                    }
                    .bold()
                    .disabled(!canAdvanceToNextStep)
                }
            }
        } footer: {
            EmptyView()
        }
        .disablePadding([.horizontal, .bottom])
        .makeBackgroundMatchFormBackground()
    }
    
    private var canAdvanceToNextStep: Bool {
        screeningData.allPropertiesAreNonnil
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
            if !Spezi.didLoadFirebase {
                // load the firebase modules into Spezi, and give it a couple seconds to fully configure everything
                // the crux here is that there isn't a mechanism by which Firebase would let us know when it
                Spezi.loadFirebase(for: region)
                try? await Task.sleep(for: .seconds(3))
            }
            do {
                try await studyLoader.update()
            } catch {
                path.append(customView: UnableToLoadStudyDefinitionStep())
                return
            }
            path.nextStep()
        } else {
            path.append(customView: NotEligibleView())
        }
    }
}
