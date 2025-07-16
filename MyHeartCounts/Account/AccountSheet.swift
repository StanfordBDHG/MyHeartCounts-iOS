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
    // swiftlint:disable attributes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openAppSettings) private var openAppSettings
    @Environment(Account.self) private var account
    @Environment(\.accountRequired) private var accountRequired
    @Environment(AccountFeatureFlags.self) private var accountFeatureFlags
    // swiftlint:enable attributes
    
    @State private var isInSetup = false
    @State private var isPresentingDemographicsSheet = false
    @State private var isPresentingFeedbackSheet = false
    
    @StudyManagerQuery private var enrollments: [StudyEnrollment]
    
    var body: some View {
        NavigationStack { // swiftlint:disable:this closure_body_length
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
            .sheet(isPresented: $isPresentingDemographicsSheet) {
                NavigationStack {
                    DemographicsForm()
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Done") {
                                    isPresentingDemographicsSheet = false
                                }
                                .bold()
                            }
                        }
                }
            }
            .sheet(isPresented: $isPresentingFeedbackSheet) {
                NavigationStack {
                    FeedbackForm()
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
        Section {
            Button("Demographics") {
                isPresentingDemographicsSheet = true
            }
        }
        
        if !enrollments.isEmpty {
            Section("Study Participations") {
                ForEach(enrollments) { enrollment in
                    NavigationLink {
                        if let studyBundle = enrollment.studyBundle {
                            StudyInfoView(studyBundle: studyBundle)
                        } else {
                            Text("Study not available")
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        makeEnrolledStudyRow(for: enrollment)
                    }
                    .disabled(enrollment.studyBundle == nil)
                }
            }
        }
        if accountFeatureFlags.isDebugModeEnabled {
            debugSection
        }
        Section {
            if let enrollment = enrollments.first, let studyBundle = enrollment.studyBundle {
                NavigationLink("Study Information") {
                    StudyInfoView(studyBundle: studyBundle)
                }
            }
            NavigationLink("Review Consent Forms") {
                SignedConsentForms()
            }
        }
        Section {
            Button {
                openAppSettings()
            } label: {
                Label("Change Language", systemSymbol: .globe)
            }
            Button {
                isPresentingFeedbackSheet = true
            } label: {
                Label("Send Feedback", systemSymbol: .textBubble)
            }
        }
        Section {
            LabeledContent {
                let bundle = Bundle.main
                Text("\(bundle.appVersion) (\(bundle.appBuildNumber ?? -1))")
            } label: {
                Label("My Heart Counts", systemSymbol: .infoCircle)
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
            }

            NavigationLink {
                ContributionsList(projectLicense: .mit)
            } label: {
                Label("License Information", systemSymbol: .buildingColumns)
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
            }
        }
    }
    
    @ViewBuilder private var debugSection: some View {
        Section("Debug Mode") {
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
    
    init(dismissAfterSignIn: Bool = true) {
        self.dismissAfterSignIn = dismissAfterSignIn
    }
    
    
    @ViewBuilder
    private func makeEnrolledStudyRow(for enrollment: StudyEnrollment) -> some View {
        if let studyInfo = enrollment.studyBundle?.studyDefinition.metadata {
            VStack(alignment: .leading) {
                Text(studyInfo.title)
                    .font(.headline)
                Text(studyInfo.shortExplanationText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Enrolled since: \(enrollment.enrollmentDate, format: .dateTime)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Study not available")
                .foregroundStyle(.secondary)
        }
    }
}
