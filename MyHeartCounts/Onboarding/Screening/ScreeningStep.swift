//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct ScreeningStep<Content: View, Footer: View>: View {
    @Environment(OnboardingNavigationPath.self)
    private var path
    
    private let title: LocalizedStringResource
    private let content: @MainActor () -> Content
    private let footer: (@MainActor () -> Footer)?
    // TODO if we have this as a normal property, do changes here cause a full view reload? would we need it as a binding?
    private let canContinue: Bool
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(
                title: "Screening: \(title.localizedString())",
                subtitle: "Before we can continue,\nwe need to learn a little about you"
            )
        } contentView: {
            content()
        } actionView: {
            OnboardingActionsView("Continue") {
                path.nextStep()
            }
            .disabled(!canContinue)
            if let footer {
                footer()
            }
        }
    }
    
    init(
        title: LocalizedStringResource,
        canContinue: Bool,
        @ViewBuilder content: @MainActor @escaping () -> Content
    ) where Footer == EmptyView {
        self.title = title
        self.content = content
        self.canContinue = canContinue
        self.footer = nil
    }
    
    init(
        title: LocalizedStringResource,
        canContinue: Bool,
        @ViewBuilder content: @MainActor @escaping () -> Content,
        @ViewBuilder footer: @MainActor @escaping () -> Footer
    ) {
        self.title = title
        self.content = content
        self.canContinue = canContinue
        self.footer = footer
    }
}


/// A simple ``ScreeningStep`` that asks for a boolean value.
struct BooleanScreeningStep: View {
    struct OptionTitles {
        let yesTitle: LocalizedStringResource
        let noTitle: LocalizedStringResource
    }
    
    private let title: LocalizedStringResource
    private let question: LocalizedStringResource
    private let explanation: LocalizedStringResource
    private let requiredSelection: Bool
    private let optionTitles: OptionTitles
    
    @State private var selection: Bool? // swiftlint:disable:this discouraged_optional_boolean
    
    init(
        title: LocalizedStringResource,
        question: LocalizedStringResource,
        explanation: LocalizedStringResource,
        requiredSelection: Bool = true,
        optionTitles: OptionTitles = .init(yesTitle: "Yes", noTitle: "No")
    ) {
        self.title = title
        self.question = question
        self.explanation = explanation
        self.requiredSelection = requiredSelection
        self.optionTitles = optionTitles
    }
    
    var body: some View {
        ScreeningStep(title: title, canContinue: selection == requiredSelection) {
            Form {
                Section {
                    Text(question)
                }
                Section {
                    Picker("", selection: $selection) {
                        Text(optionTitles.yesTitle).tag(true)
                        Text(optionTitles.noTitle).tag(false)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text(explanation)
                }
            }
        }
    }
}
