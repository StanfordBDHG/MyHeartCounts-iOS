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
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    @Environment(MyHeartCountsStandard.self)
    private var standard
    @Environment(Account.self)
    private var account
    @Environment(\.locale)
    private var locale
    
    @State private var consentDocument: ConsentDocument?
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingConsentView(consentDocument: consentDocument) {
            guard let consentDocument else {
                return
            }
            let pdf = try consentDocument.export(using: .init(paperSize: locale.preferredPaperSize))
            try await standard.importConsentDocument(pdf, for: .generalAppUsage)
            path.nextStep()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ConsentShareButton(consentDocument: consentDocument, viewState: $viewState)
            }
        }
        .task {
            if consentDocument == nil {
                let url = Bundle.main.url(forResource: "Consent", withExtension: "md")! // swiftlint:disable:this force_unwrapping
                consentDocument = try? ConsentDocument(
                    contentsOf: url,
                    initialName: account.details?.name
                )
            }
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
