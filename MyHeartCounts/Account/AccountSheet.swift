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
    
    @StudyManagerQuery private var enrollments: [StudyEnrollment]
    
    @LocalPreference(.enableDebugMode)
    private var enableDebugMode
    
    @State private var debugModeLabelId = UUID()
    
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
        if !enrollments.isEmpty {
            Section("Study Participations") {
                ForEach(enrollments) { enrollment in
                    NavigationLink {
                        if let study = enrollment.study {
                            StudyInfoView(study: study)
                        } else {
                            Text("Study not available")
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        makeEnrolledStudyRow(for: enrollment)
                    }
                    .disabled(enrollment.study == nil)
                }
            }
        }
        Section("Debug Mode") {
            Toggle("Enable Debug Mode", isOn: $enableDebugMode)
            if enableDebugMode {
                NavigationLink("Health Data Bulk Upload") {
                    HealthImporterControlView()
                }
                NavigationLink("NotificationsManager") {
                    NotificationsManagerControlView()
                }
                NavigationLink("Debug Stuff") {
                    DebugStuffView()
                }
            }
        }
        Section {
            if let enrollment = enrollments.first, let study = enrollment.study {
                NavigationLink("Study Information") {
                    StudyInfoView(study: study)
                }
            }
            NavigationLink("Review Consent Forms") {
                SignedConsentForms()
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
    private func makeEnrolledStudyRow(for enrollment: StudyEnrollment) -> some View {
        if let study = enrollment.study {
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
