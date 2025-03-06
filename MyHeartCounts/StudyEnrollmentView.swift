//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SpeziStudy
import SpeziViews
import SpeziHealthKit
import SwiftData


/// View that lets you pick a study (or multiple) to enroll in.
struct StudyEnrollmentView: View {
    private enum ViewState: Hashable {
        case loading
        case loaded([StudyDefinition])
    }
    @Environment(\.dismiss) private var dismiss
    
    @Query private var SPCs: [StudyParticipationContext]
    @State private var state: ViewState = .loading
    
    let selectionHandler: @MainActor (StudyDefinition) -> Void
    
    var body: some View {
        NavigationStack { // swiftlint:disable:this closure_body_length
            Group {
                switch state {
                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .loaded(let studies):
                    let studies = studies.sorted(using: KeyPathComparator(\.metadata.title))
                    // "new" as in not-yet-enrolled
                    let newStudies = studies.filter { study in !SPCs.contains { $0.study.id == study.id } }
                    let alreadyEnrolledStudies = studies.filter { study in SPCs.contains { $0.study.id == study.id } }
                    Form {
                        makeStudiesSection("Available Studies", studies: newStudies)
                        makeStudiesSection("Already Enrolled", studies: alreadyEnrolledStudies)
                    }
                }
            }
            .navigationTitle("Available Studies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton()
                }
            }
            .task {
                state = .loaded([mockMHCStudy])
            }
        }
    }
    
    
    @ViewBuilder
    private func makeStudiesSection(_ title: LocalizedStringResource, studies: [StudyDefinition]) -> some View {
        if !studies.isEmpty {
            Section(String(localized: title)) {
                ForEach(studies) { study in
                    let isUnavailableBcMissingDependency: Bool = { () -> Bool in // TODO instead of just disabling it, hide it entirely???
                        if let dependency = study.metadata.studyDependency {
                            // studies w/ a dependency are only allowed if the user is already in the other study
                            return !SPCs.contains(where: { $0.study.id == dependency })
                        } else {
                            // studies w/out a dependency are always allowed
                            return false
                        }
                    }()
                    Section {
                        NavigationLink {
                            StudyInfoView(study: study, dismiss: dismiss)
//                                    DetailedStudyInfoView(study: study) { study in
//                                        dismiss()
//                                        selectionHandler(study)
//                                    }
                        } label: {
                            studyRowView(for: study)
                            if isUnavailableBcMissingDependency {
                                Text("Unavailable: not enrolled into parent(dep) study.")
                            }
                        }.disabled(isUnavailableBcMissingDependency)
                    }
                }
            }
        }
    }
    
    
    @ViewBuilder
    private func studyRowView(for study: StudyDefinition) -> some View {
        HStack {
            Group {
                switch study.metadata.icon {
                case nil:
                    EmptyView()
                case .systemSymbol(let name):
                    Image(systemName: name).resizable().aspectRatio(contentMode: .fit).padding(.horizontal, 8)
                case .custom(let data):
                    AsyncImage2(data: data)
                }
            }.frame(width: 47)
            VStack(alignment: .leading) {
                Text(study.metadata.title)
                    .font(.headline.bold())
                Text(study.metadata.shortExplanationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
