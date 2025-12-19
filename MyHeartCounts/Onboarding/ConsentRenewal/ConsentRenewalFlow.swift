//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import SFSafeSymbols
import SpeziAccount
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct ConsentRenewalFlow: View {
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        ManagedNavigationStack {
            ConsentRenewalExplainer()
            Consent {
                dismiss()
            }
        }
        .interactiveDismissDisabled()
    }
}


private struct ConsentRenewalExplainer: View {
    // swiftlint:disable attributes
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(Account.self) private var account: Account?
    // swiftlint:enable attributes
    
    var body: some View {
        OnboardingView {
            VStack(alignment: .leading) {
                OnboardingTitleView(title: "Consent Renewal")
                Spacer()
                HStack {
                    Spacer()
                    Image(systemSymbol: .textDocument)
                        .font(.system(size: 150))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                    Spacer()
                }
                Spacer()
                let lastSignDate = account?.details?.lastSignedConsentDate
                Text("""
                    Our Study Consent document has been updated since you last signed it\(lastSignDate.map { " on \($0.formatted(.dateTime))" } ?? "").
                    
                    Please review the new Consent document and sign it again.
                    """)
                Spacer()
            }
        } footer: {
            OnboardingActionsView("OK") {
                path.nextStep()
            }
        }
    }
}
