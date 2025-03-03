//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziOnboarding
import SwiftUI


struct Consent: View {
    @Environment(OnboardingNavigationPath.self) private var path
    @Environment(MHC.self) private var mhc
    
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
                """
                # My Heart Counts
                Welcome to **MHC** (the _app_ that *will* xxx)
                
                ## Heading2
                - This
                - is
                - a
                - List!!!
                
                We need you to agree to the following things:
                - [] one
                - [] two
                - [] three
                - [] four
                """.data(using: .utf8)!
            },
            action: { document in
                mhc.importConsentDocument(document, for: .generalAppUsage)
                path.nextStep()
            },
            title: "Onboarding Consent Title",
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
