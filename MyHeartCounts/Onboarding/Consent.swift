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
import SpeziStudy
import SpeziViews
import SwiftUI


struct Consent: View {
    // swiftlint:disable attributes
    @Environment(\.dismiss) private var dismiss
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(OnboardingDataCollection.self) private var onboardingData
    @Environment(MyHeartCountsStandard.self) private var standard
    @Environment(Account.self) private var account
    @Environment(StudyBundleLoader.self) private var studyLoader
    // NOTE: at this step, we aren't yet enrolled into the study,
    // so we can't access `studyManager.enrollments`, but we CAN access
    // `studyManager.preferredLocale`, since that has been set in a previous step.
    @Environment(StudyManager.self) private var studyManager
    // swiftlint:enable attributes
    
    @State private var consentDocument: ConsentDocument?
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        OnboardingConsentView(consentDocument: consentDocument, title: nil, viewState: $viewState) {
            guard let consentDocument else {
                return
            }
            onboardingData.consentResponses = consentDocument.userResponses
            let result = try consentDocument.export(using: pdfExportConfig)
            try await standard.uploadConsentDocument(result)
            do {
                var accountDetailUpdates = AccountDetails()
                accountDetailUpdates.lastSignedConsentDate = .now
                accountDetailUpdates.lastSignedConsentVersion = consentDocument.metadata.version?.description
                let modifications = try AccountModifications(modifiedDetails: accountDetailUpdates)
                try await account.accountService.updateAccountDetails(modifications)
            }
            if !path.nextStep() {
                dismiss()
            }
        }
        .navigationTitle("Consent")
        .scrollIndicators(.visible)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ConsentShareButton(
                    consentDocument: consentDocument,
                    exportConfiguration: pdfExportConfig,
                    viewState: $viewState
                )
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
    
    private var pdfExportConfig: ConsentDocument.ExportConfiguration {
        ConsentDocument.ExportConfiguration(
            paperSize: studyManager.preferredLocale.preferredPaperSize
        )
    }
    
    private func loadConsentDocument() async throws {
        guard consentDocument == nil else {
            return
        }
        guard let studyBundle = try? studyLoader.studyBundle?.get(),
              let consentFileRef = studyBundle.studyDefinition.metadata.consentFileRef,
              let text = studyBundle.consentText(for: consentFileRef, in: studyManager.preferredLocale) else {
            return
        }
        consentDocument = try ConsentDocument(
            markdown: text,
            initialName: account.details?.name
        )
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
