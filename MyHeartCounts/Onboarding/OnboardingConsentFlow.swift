//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable attributes file_types_order

import SFSafeSymbols
import Spezi
import SpeziAccount
import SpeziConsent
import SpeziFoundation
import SpeziOnboarding
import SpeziStudy
import SpeziViews
import SwiftUI


struct OnboardingConsentFlow: View {
    // swiftlint:disable attributes
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(ConsentManager.self) private var consentManager
    // swiftlint:enable attributes
    
    @State private var consentDoc: ConsentDocument?
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingPage(
            symbol: .signature,
            title: "Consent",
            description: ""
        ) {
            switch viewState {
            case .idle, .processing:
                ProgressView("Loading Consent Document…" as String)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .center)
            case .error(let error):
                ContentUnavailableView("Error", systemSymbol: .exclamationmarkOctagon, description: Text(error.localizedDescription))
            }
        }
        .task {
            do {
                viewState = .processing
                let doc = try await loadConsentDocument()
                switch try consentManager.shouldSign(doc.metadata) {
                case .no:
                    // the user does not need to go through the whole flow,
                    // so we go to the next regularly scheduled step
                    path.nextStep()
                case .yes:
                    // the user needs to go through the whole consent flow
                    path.append {
                        Disclaimers(consentDoc: doc)
                            .navigationBarBackButtonHidden()
                    }
                }
            } catch {
                viewState = .error(AnyLocalizedError(error: error))
            }
        }
    }
    
    private func loadConsentDocument() async throws -> ConsentDocument {
        if let consentDoc {
            return consentDoc
        }
        let doc = try await consentManager.loadConsentDoc()
        consentDoc = doc
        return doc
    }
}


private struct Disclaimers: View {
    struct DisclaimerConfig {
        let icon: SFSymbol
        let title: LocalizedStringResource
        let primaryText: LocalizedStringResource
        let learnMoreText: LocalizedStringResource
        let stepId: OnboardingStep
    }
    
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    let step: DisclaimerConfig
    let trailingSteps: [DisclaimerConfig]
    let consentDoc: ConsentDocument
    
    @State private var isShowingLearnMoreText = false
    
    var body: some View {
        OnboardingPage(symbol: step.icon, title: step.title, description: step.primaryText) {
            EmptyView()
        } footer: {
            actionButtons
        }
        .sheet(isPresented: $isShowingLearnMoreText) {
            OnboardingLearnMore(title: step.title, learnMoreText: step.learnMoreText)
        }
        .onboardingStep(step.stepId)
        .injectingSpezi()
    }
    
    private var actionButtons: some View {
        OnboardingActionsView(
            primaryTitle: "Continue",
            primaryAction: {
                next()
            },
            secondaryTitle: "Learn More",
            secondaryAction: {
                isShowingLearnMoreText = true
            }
        )
    }
    
    init(step: DisclaimerConfig, trailing trailingSteps: some Collection<DisclaimerConfig>, consentDoc: ConsentDocument) {
        self.step = step
        self.trailingSteps = Array(trailingSteps)
        self.consentDoc = consentDoc
    }
    
    private func next() {
        if let next = trailingSteps.first {
            path.append {
                Self(step: next, trailing: trailingSteps.dropFirst(), consentDoc: consentDoc)
            }
        } else {
            // we've gone through all disclaimers, the next step is the Consent Comprehension
            path.append {
                ComprehensionScreening(consentDoc: consentDoc)
            }
        }
    }
}


extension Disclaimers {
    init(consentDoc: ConsentDocument) {
        let steps: [DisclaimerConfig] = [
            .init(
                icon: .textPageBadgeMagnifyingglass,
                title: "ONBOARDING_DISCLAIMER_1_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_1_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_1_LEARN_MORE_TEXT",
                stepId: .disclaimer1
            ),
            .init(
                icon: .figureWalkMotion,
                title: "ONBOARDING_DISCLAIMER_2_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_2_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_2_LEARN_MORE_TEXT",
                stepId: .disclaimer2
            ),
            .init(
                icon: .lockSquareStack,
                title: "ONBOARDING_DISCLAIMER_3_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_3_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_3_LEARN_MORE_TEXT",
                stepId: .disclaimer3
            ),
            .init(
                icon: .documentOnClipboard,
                title: "ONBOARDING_DISCLAIMER_4_TITLE",
                primaryText: "ONBOARDING_DISCLAIMER_4_PRIMARY_TEXT",
                learnMoreText: "ONBOARDING_DISCLAIMER_4_LEARN_MORE_TEXT",
                stepId: .disclaimer4
            )
        ]
        self.init(step: steps[0], trailing: steps.dropFirst(), consentDoc: consentDoc)
    }
}


#if DEBUG
extension ConsentDocument {
    /// Intended for use in SwiftUI `#Preview`s within MHC
    static let previewDoc = try! ConsentDocument(markdown: "Consent Text") // swiftlint:disable:this force_try
}
#endif
