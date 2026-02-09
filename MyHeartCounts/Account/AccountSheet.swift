//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseCore
import FirebaseFunctions
import SFSafeSymbols
import SpeziAccount
import SpeziHealthKitBulkExport
import SpeziLicense
import SpeziSensorKit
import SpeziStudy
import SpeziViews
import SwiftUI


struct AccountSheet: View {
    private let dismissAfterSignIn: Bool
    // swiftlint:disable attributes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openUrl
    @Environment(\.openSettingsApp) private var openSettingsApp
    @Environment(Account.self) private var account
    @Environment(HistoricalHealthSamplesExportManager.self) private var historicalDataExportMgr
    @Environment(ManagedFileUpload.self) private var managedFileUpload
    @Environment(SensorKitDataFetcher.self) private var sensorKitDataFetcher
    // swiftlint:enable attributes
    
    @State private var isInSetup = false
    @State private var isPresentingFeedbackSheet = false
    
    @AccountFeatureFlagQuery(.isDebugModeEnabled)
    private var debugModeEnabled
    
    @StudyManagerQuery private var enrollments: [StudyEnrollment]
    
    var body: some View {
        NavigationStack {
            ZStack {
                if account.signedIn && !isInSetup {
                    AccountOverview(close: .showCloseButton, deletion: .disabled) {
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
                }
            }
            .sheet(isPresented: $isPresentingFeedbackSheet) {
                NavigationStack {
                    FeedbackForm()
                }
            }
        }
    }
    
    @ViewBuilder private var accountSheetExtraContent: some View {
        if SensorKit.isAvailable {
            Section {
                SensorKitButton()
            }
        }
        if let enrollment = enrollments.first {
            Section("Study Participation") { // swiftlint:disable:this closure_body_length
                Button {
                    openUrl(MyHeartCounts.website)
                } label: {
                    HStack {
                        makeEnrolledStudyRow(for: enrollment)
                        Spacer()
                        DisclosureIndicator()
                    }
                    .contentShape(Rectangle())
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
                }
                NavigationLink("Review Consent Forms") {
                    SignedConsentForms()
                }
                if let text = { () -> LocalizedStringResource? in
                    switch (isProcessingHealthData, isProcessingSensorKitData) {
                    case (true, true):
                        "Processing Health and SensorKit Data…"
                    case (true, false):
                        "Processing Health Data…"
                    case (false, true):
                        "Processing SensorKit Data…"
                    case (false, false):
                        nil
                    }
                }() {
                    let label = HStack {
                        Text(text)
                        Spacer()
                        ProgressView()
                    }
                    if debugModeEnabled {
                        NavigationLink {
                            DataProcessingDebugView()
                        } label: {
                            label
                        }
                    } else {
                        label
                    }
                }
            }
        }
        Section {
            Button {
                openSettingsApp()
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
            AboutRow()
            NavigationLink {
                ContributionsList(projectLicense: .mit)
            } label: {
                Label("License Information", systemSymbol: .buildingColumns)
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
            }
            if debugModeEnabled || FeatureFlags.isTakingDemoScreenshots {
                NavigationLink {
                    DebugForm()
                } label: {
                    Label("Debug", systemSymbol: .wrenchAdjustable)
                        .foregroundStyle(colorScheme.textLabelForegroundStyle)
                }
            }
        }
    }
    
    private var isProcessingHealthData: Bool {
        let uploadCategories = [ManagedFileUpload.Category.liveHealthUpload, .historicalHealthUpload]
        return historicalDataExportMgr.session.map { $0.state == .running || $0.state == .paused } ?? false
            || uploadCategories.contains(where: { managedFileUpload.isActive($0) })
    }
    
    private var isProcessingSensorKitData: Bool {
        managedFileUpload.progressByCategory.keys.contains { $0.id.contains("SensorKit") }
            || !sensorKitDataFetcher.activeActivities.isEmpty
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


extension AccountSheet {
    private struct AboutRow: View {
        @Environment(\.colorScheme)
        private var colorScheme
        
        @StudyManagerQuery private var enrollments: [StudyEnrollment]
        
        @State private var showExtendedInfo = false
        
        var body: some View {
            LabeledContent {
                let bundle = Bundle.main
                if !showExtendedInfo {
                    Text(bundle.appVersion)
                } else {
                    Text(verbatim: "\(bundle.appVersion) (\(bundle.appBuildNumber ?? -1))")
                }
            } label: {
                Label(symbol: .infoCircle) {
                    VStack(alignment: .leading) {
                        Text("My Heart Counts")
                        if showExtendedInfo {
                            extendedInfo
                        }
                    }
                }
                .foregroundStyle(colorScheme.textLabelForegroundStyle)
            }
            .onTapGesture(count: 3) {
                showExtendedInfo = true
            }
        }
        
        private var extendedInfo: some View {
            HStack {
                if let firebaseProjectId = FirebaseApp.app()?.options.projectID {
                    Text(firebaseProjectId)
                }
                if let enrollment = enrollments.first {
                    Text(verbatim: "rev=\(enrollment.studyRevision)")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}
