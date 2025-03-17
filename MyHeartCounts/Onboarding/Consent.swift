//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziOnboarding
import SpeziStudy
import SwiftUI


struct Consent: View {
    @Environment(OnboardingNavigationPath.self)
    private var path
    @Environment(StudyManager.self)
    private var studyManager
    
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
                try! await studyManager.importConsentDocument(document, for: .generalAppUsage) // swiftlint:disable:this force_try
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
