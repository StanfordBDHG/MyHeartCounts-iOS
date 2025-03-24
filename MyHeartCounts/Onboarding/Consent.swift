//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziAccount
import SpeziOnboarding
import SwiftUI


struct Consent: View {
    @Environment(OnboardingNavigationPath.self)
    private var path
    
    @Environment(MyHeartCountsStandard.self)
    private var standard
    
    @Environment(Account.self)
    private var account
    
    private var consentDocument: Data {
        guard let path = Bundle.main.url(forResource: "ConsentDocument", withExtension: "md"),
              let data = try? Data(contentsOf: path) else {
            return Data(String(localized: "CONSENT_LOADING_ERROR").utf8)
        }
        return data
    }
    
    
    var body: some View {
        OnboardingConsentView(
            markdown: {
                consentDocument
            },
            action: { document in
                // TOOD deliver this to the standard instead?!
                nonisolated(unsafe) let document = document
                try! await standard.importConsentDocument(document, for: .generalAppUsage) // swiftlint:disable:this force_try
                path.nextStep()
            },
            title: "Onboarding Consent Title",
            initialNameComponents: account.details?.name,
            currentDateInSignature: true,
            exportConfiguration: .init(
                paperSize: .usLetter,
                consentTitle: "Consent Export Title",
                includingTimestamp: true,
                fontSettings: .defaultExportFontSettings
            )
        )
    }
}


#if DEBUG
#Preview {
    OnboardingStack {
        Consent()
    }
    .previewWith(standard: MyHeartCountsStandard()) {
//        OnboardingDataSource()
    }
}
#endif
