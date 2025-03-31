//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziAccount
import SpeziLicense
import SpeziStudy
import SwiftData
import SwiftUI


struct AccountSheet: View {
    private let dismissAfterSignIn: Bool

    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(Account.self)
    private var account
    @Environment(\.accountRequired)
    private var accountRequired
    
    @State private var isInSetup = false
    
    @StudyManagerQuery private var SPCs: [StudyParticipationContext]
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                if account.signedIn && !isInSetup {
                    AccountOverview(close: .showCloseButton) {
                        accountSheetExtraContent
                    }
                } else {
                    AccountSetup { _ in
                        if dismissAfterSignIn {
                            dismiss() // we just signed in, dismiss the account setup sheet
                        }
                    } header: {
                        AccountSetupHeader()
                    }
                        .onAppear {
                            isInSetup = true
                        }
                        .toolbar {
                            if !accountRequired {
                                closeButton
                            }
                        }
                }
            }
        }
    }

    @ToolbarContentBuilder private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                dismiss()
            }
        }
    }
    
    @ViewBuilder private var accountSheetExtraContent: some View {
        if !SPCs.isEmpty {
            Section("Study Participations") {
                ForEach(SPCs) { SPC in
                    NavigationLink {
                        if let study = SPC.study {
                            StudyInfoView(study: study)
                        } else {
                            Text("Study not available")
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        makeEnrolledStudyRow(for: SPC)
                    }
                    .disabled(SPC.study == nil)
                }
            }
        }
        Section {
            NavigationLink {
                ContributionsList(projectLicense: .mit)
            } label: {
                Text("License Information")
            }
        }
    }

    init(dismissAfterSignIn: Bool = true) {
        self.dismissAfterSignIn = dismissAfterSignIn
    }
    
    
    @ViewBuilder
    private func makeEnrolledStudyRow(for SPC: StudyParticipationContext) -> some View {
        if let study = SPC.study {
            VStack(alignment: .leading) {
                Text(study.metadata.title)
                    .font(.headline)
                Text(study.metadata.shortExplanationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("TODO MAYBE ALSO: enrollment date/duration, short list of which data are being shared/collected")
            }
        } else {
            Text("Study not available")
                .foregroundStyle(.secondary)
        }
    }
}


#if DEBUG
#Preview("AccountSheet") {
    var details = AccountDetails()
    details.userId = "lelandstanford@stanford.edu"
    details.name = PersonNameComponents(givenName: "Leland", familyName: "Stanford")
    
    return AccountSheet()
        .previewWith {
            AccountConfiguration(service: InMemoryAccountService(), activeDetails: details)
        }
}

#Preview("AccountSheet SignIn") {
    AccountSheet()
        .previewWith {
            AccountConfiguration(service: InMemoryAccountService())
        }
}
#endif
