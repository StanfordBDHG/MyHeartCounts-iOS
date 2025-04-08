//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit
import SpeziStudy
import SpeziViews
import SwiftData
import SwiftUI


public struct StudyInfoView: View { // swiftlint:disable:this file_types_order
    @Environment(StudyManager.self)
    private var mhc
    @Environment(\.dismiss)
    private var _dismiss
    
    @StudyManagerQuery private var enrollments: [StudyEnrollment]
    @State private var viewState: ViewState = .idle
    @State private var isPresentingUnenrollConfirmationDialog = false
    
    private let study: StudyDefinition
    private let injectedDismiss: DismissAction?
    
    private var dismiss: DismissAction {
        injectedDismiss ?? _dismiss
    }
    
    public var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Text(study.metadata.title)
                        .font(.title.bold())
                    Text(study.metadata.shortExplanationText)
                }
                .listRowBackground(Color.clear)
            }
            Section {
                Text(study.metadata.explanationText)
            }
            Section {
                Text("TODO: rough information about (at least some) key study components here?")
            }
            healthDataCollectionSection
            Section {
                StudyParticipationCriteriaView(criterion: study.metadata.participationCriteria.criterion)
            } header: {
                Text("Participation Criteria")
            } footer: {
                Text("TODO: make this look pretty!")
            }
            Section {
                mainAction
            }
        }
        .interactiveDismissDisabled(viewState != .idle)
    }
    
    
    @ViewBuilder private var healthDataCollectionSection: some View {
        let collectedSampleTypes = study.allCollectedHealthData
        if !collectedSampleTypes.isEmpty {
            Section("Health Data") {
                VStack(alignment: .leading) {
                    Text("This study will request read-access to collect the following Health samples:")
                    let allSampleTypes: [any AnySampleType] = (Array(collectedSampleTypes.quantityTypes) as [any AnySampleType])
                        .appending(contentsOf: Array(collectedSampleTypes.correlationTypes) as [any AnySampleType])
                        .appending(contentsOf: Array(collectedSampleTypes.categoryTypes) as [any AnySampleType])
                        .sorted(by: { $0.displayTitle < $1.displayTitle })
                    ForEach(0..<allSampleTypes.endIndex, id: \.self) { (sampleTypeIdx: Int) in
                        let sampleType = allSampleTypes[sampleTypeIdx]
                        Text("– \(sampleType.displayTitle)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    
    @ViewBuilder private var mainAction: some View {
        Group { // swiftlint:disable:this closure_body_length
            if let enrollment = enrollments.first(where: { $0.studyId == study.id }) {
                // already enrolled
                Button {
                    isPresentingUnenrollConfirmationDialog = true
                } label: {
                    HStack {
                        Spacer()
                        Text("End Study Participation").bold()
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tint(.red)
                .confirmationDialog(
                    "Are you sure you want to leave the '\(study.metadata.title)' study?",
                    isPresented: $isPresentingUnenrollConfirmationDialog
                ) {
                    Button("Cancel", role: .cancel) {
                        isPresentingUnenrollConfirmationDialog = false
                    }
                    Button("Unenroll", role: .destructive) {
                        if true {
                            // intentionally disabled atm.
                            // https://www.notion.so/stanfordbdhg/MHC-questions-thoughts-1a1008f9653880c68ffbefeaf050609f?pvs=4#1c9008f965388097a5a4d2e137ec3f4e
                            return
                        }
                        _Concurrency.Task {
                            viewState = .processing
                            do {
                                try mhc.unenroll(from: enrollment)
                                dismiss()
                            } catch {
                                viewState = .error(AnyLocalizedError(error: error))
                            }
                        }
                    }
                }
            } else {
                // not yet enrolled
                AsyncButton(state: $viewState) {
                    try await mhc.enroll(in: study)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("Enroll in Study").bold()
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .listRowInsets(EdgeInsets())
        .frame(height: 52)
    }
    
    
    public init(study: StudyDefinition, dismiss: DismissAction? = nil) {
        self.study = study
        self.injectedDismiss = dismiss
    }
}


private struct StudyParticipationCriteriaView: View {
    let criterion: StudyDefinition.ParticipationCriteria.Criterion
    
    var body: some View {
        VStack(alignment: .leading) {
            subView(for: criterion, indentLevel: 0)
        }
    }
    
    
    private func subView(for criterion: StudyDefinition.ParticipationCriteria.Criterion, indentLevel: Int) -> AnyView {
        AnyView {
            switch criterion {
            case .ageAtLeast(let minAge):
                Text(indent: indentLevel, "- Age ≥ \(minAge)")
            case .isFromRegion(let region):
                Text(indent: indentLevel, "- From Region \(region.identifier)")
            case .speaksLanguage(let language):
                Text(indent: indentLevel, "- Speaks Language \(language.maximalIdentifier)")
            case .custom(let customCriterionKey):
                Text(indent: indentLevel, customCriterionKey.displayTitle)
            case .not(let criterion):
                Text(indent: indentLevel, "- NOT:")
                subView(for: criterion, indentLevel: indentLevel + 1)
            case .all(let criteria):
                Text(indent: indentLevel, "- All of the following:")
                ForEach(0..<criteria.endIndex, id: \.self) { idx in
                    subView(for: criteria[idx], indentLevel: indentLevel + 1)
                }
            case .any(let criteria):
                Text(indent: indentLevel, "- Any of the following:")
                ForEach(0..<criteria.endIndex, id: \.self) { idx in
                    subView(for: criteria[idx], indentLevel: indentLevel + 1)
                }
            }
        }
    }
}


extension Text {
    init(indent: Int, _ string: some StringProtocol) {
        self.init(verbatim: String(repeating: "\t", count: indent) + string)
    }
}


extension AnyView {
    init(@ViewBuilder _ content: () -> some View) {
        self.init(erasing: content())
    }
}
