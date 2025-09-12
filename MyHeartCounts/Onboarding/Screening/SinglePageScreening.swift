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

/// The ``SinglePageScreening`` view consists of components, each of which should collect one piece of information from the user, and is placed in its own `Section`.
protocol ScreeningComponent: View {
    /// The user-displayed title of this component.
    ///
    /// Will be used as the `Section` title in the UI.
    var title: LocalizedStringResource { get }
    
    /// Determines, based on the collected data, whether the user-entered value sasisfies the component's requirements.
    ///
    /// - Note: this function will be called outside of the component being installed in a SwiftUI hierarchy!
    func evaluate(_ data: OnboardingDataCollection) -> Bool
}


/// A Screening View, that collects all data on a single page.
///
/// Intended to be used in an `OnboardingStack`.
struct SinglePageScreening: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    @Environment(OnboardingDataCollection.self)
    private var data
    
    private let title: LocalizedStringResource
    private let subtitle: LocalizedStringResource
    private let components: [any ScreeningComponent]
    private let didAnswerAllRequestedFields: @MainActor (OnboardingDataCollection) -> Bool
    private let continueAction: @MainActor (_ data: OnboardingDataCollection, _ path: ManagedNavigationStack.Path) async -> Void
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingView(wrapInScrollView: false) {
            OnboardingTitleView(title: title, subtitle: subtitle)
                .padding(.horizontal)
        } content: {
            Form {
                ForEach(0..<components.endIndex, id: \.self) { idx in
                    let component = components[idx]
                    let title = String(localized: component.title)
                    Section {
                        component.intoAnyView()
                    } header: {
                        if !title.isEmpty {
                            Text(title)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("Screening Section, \(title.isEmpty ? String(idx) : title)")
                }
                Section {
                    AsyncButton(state: $viewState) {
                        await evaluateEligibilityAndProceed()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdvanceToNextStep)
                    .listRowInsets(.zero)
                }
            }
        } footer: {
            EmptyView()
        }
        .disablePadding([.horizontal, .bottom])
        .makeBackgroundMatchFormBackground()
    }
    
    private var canAdvanceToNextStep: Bool {
        didAnswerAllRequestedFields(data)
//        // NOTE: ideally we'd simply use Mirror here to get a list of all properties,
//        // and then do a simple `allSatisfy { value != nil }`, but that doesn't work,
//        // because, even though we absolutely can use this code to get this result,
//        // reading the property value through the Mirror won't call `access`, meaning that
//        // using this propertu from SwiftUI won't cause view updates if any of the
//        // properties change.
//        screeningData.dateOfBirth != nil && screeningData.region != nil && screeningData.speaksEnglish != nil && screeningData.physicalActivity != nil
    }
    
    init(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        @ArrayBuilder<any ScreeningComponent> components: () -> [any ScreeningComponent],
        didAnswerAllRequestedFields: @escaping @MainActor (OnboardingDataCollection) -> Bool,
        continue continueAction: @escaping @MainActor (_ data: OnboardingDataCollection, _ path: ManagedNavigationStack.Path) async -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.components = components()
        self.didAnswerAllRequestedFields = didAnswerAllRequestedFields
        self.continueAction = continueAction
    }
    
    private func evaluateEligibilityAndProceed() async {
        await continueAction(data, path)
    }
}
