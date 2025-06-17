//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziAccount
import SpeziConsent
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct Consent: View {
    // swiftlint:disable attributes
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(MyHeartCountsStandard.self) private var standard
    @Environment(Account.self) private var account
    @Environment(\.locale) private var locale
    @Environment(StudyDefinitionLoader.self) private var definitionLoader
    // swiftlint:enable attributes
    
    @State private var consentDocument: ConsentDocument?
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingConsentView(consentDocument: consentDocument, title: nil) {
            guard let consentDocument else {
                return
            }
            let pdf = try consentDocument.export(using: .init(paperSize: locale.preferredPaperSize))
            try await standard.importConsentDocument(pdf, for: .generalAppUsage)
            path.nextStep()
        }
        .navigationTitle("Consent")
        .scrollIndicators(.visible)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ConsentShareButton(consentDocument: consentDocument, viewState: $viewState)
            }
        }
        .task {
            do {
                try await loadConsentDocument()
            } catch {
                logger.error("Failed to load/create ConsentDocument: \(error)")
            }
        }
    }
    
    private func loadConsentDocument() async throws {
        logger.notice("will load consent document")
        guard consentDocument == nil else {
            return
        }
        if let text = try? definitionLoader.consentDocument?.get() {
            consentDocument = try ConsentDocument(
                markdown: text,
                initialName: account.details?.name
            )
        }
    }
}


extension Locale {
    fileprivate var preferredPaperSize: ConsentDocument.ExportConfiguration.PaperSize {
        switch self.region {
        case .unitedStates: .usLetter
        default: .dinA4
        }
    }
}


#if DEBUG
#Preview {
    ManagedNavigationStack {
        Consent()
    }
    .previewWith(standard: MyHeartCountsStandard()) {
//        OnboardingDataSource()
    }
}
#endif
