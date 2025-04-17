//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseStorage
import Foundation
import SpeziAccount
import SpeziFoundation
import SpeziHealthKit
import SpeziStudy
import SpeziViews
import SwiftUI


/// A `View` that allows debugging and controling the ``HealthImporter``.
///
/// Primarily intended for internal use.
struct HealthImporterControlView: View {
    @Environment(HealthKit.self)
    private var healthKit
    @Environment(BulkHealthExporter.self)
    private var bulkExporter
    
    @StudyManagerQuery private var studyEnrollments: [StudyEnrollment]
    
    @Environment(Account.self)
    private var account
    
    @State private var viewState: ViewState = .idle
    @State private var numTotalUploads = 0
    @State private var numCompletedUploads = 0
    
    
    var body: some View {
        Form {
            actionsSection
            statusSection
            ForEach(bulkExporter.sessions, id: \.sessionId) { session in
                section(for: session)
            }
        }
        .navigationTitle("Bulk Export Manager")
        .navigationBarTitleDisplayMode(.inline)
        .viewStateAlert(state: $viewState)
    }
    
    @ViewBuilder private var actionsSection: some View {
        Section {
            AsyncButton("Request full read access (Q)", state: $viewState) {
                try await healthKit.askForAuthorization(for: .init(read: HKQuantityType.allKnownQuantities))
            }
            AsyncButton("Create Session", state: $viewState) {
                guard let enrollment = studyEnrollments.first,
                      let study = enrollment.study,
                      let accountId = account.details?.accountId else {
                    print("uh oh :/")
                    return
                }
                _ = try await bulkExporter.session(
                    "MHC.bulkUpload",
                    for: study.allCollectedHealthData,
                    using: FirebaseUploadHealthExportProcessor(),
                    startAutomatically: false
                )
            }
            AsyncButton("Delete ~/HealthKitUploads/*", state: $viewState) {
                let fileManager = FileManager.default
                try fileManager.removeItem(at: .scheduledHealthKitUploads)
                try fileManager.createDirectory(at: .scheduledHealthKitUploads, withIntermediateDirectories: true)
            }
            AsyncButton("Upload ~/HealthKitUploads/*", state: $viewState) {
                try await uploadHealthBatches()
            }
        }
    }
    
    @ViewBuilder private var statusSection: some View {
        Section("Status") {
            
        }
        if numTotalUploads != 0 {
            Section("Upload Progress") {
                ProgressView(value: Double(numCompletedUploads) / Double(numTotalUploads)) {
                    Text("\(numCompletedUploads) / \(numTotalUploads) complete")
                }
            }
        }
    }
    
    @ViewBuilder
    private func section(for session: any BulkHealthExporter.ExportSessionProtocol) -> some View {
        Section {
            Text(session.sessionId)
                .monospaced()
            LabeledContent("State") {
                switch session.state {
                case .scheduled:
                    Text("scheduled")
                case .running:
                    Text("running")
                case .paused:
                    Text("paused")
                case .done:
                    Text("done")
                }
            }
            switch session.state {
            case .scheduled, .paused:
                Button("Start session") {
                    session.start()
                }
            case .running:
                Button("Pause session") {
                    session.pause()
                }
            case .done:
                EmptyView()
            }
            if let progress = session.progress {
                VStack {
                    ProgressView(value: Double(progress.currentBatchIdx) / Double(progress.numTotalBatches)) {
                        Text("Uploading batch \(progress.currentBatchIdx) of \(progress.numTotalBatches)")
                        Text("Current batch: \(progress.currentBatchDescription)")
                    }
                }
            }
        }
    }
    
    
    private func uploadHealthBatches() async throws {
        guard let accountId = account.details?.accountId else {
            return
        }
        let fileManager = FileManager.default
        try await withThrowingDiscardingTaskGroup(returning: Void.self) { taskGroup in
            let files = try fileManager.contentsOfDirectory(at: .scheduledHealthKitUploads, includingPropertiesForKeys: nil)
            self.numTotalUploads = files.count
            self.numCompletedUploads = 0
            for url in files {
                taskGroup.addTask {
                    let storage = Storage.storage()
                    let ref = storage.reference(withPath: "users/\(accountId)/bulkHealthKitUploads/\(url.lastPathComponent)")
                    try await ref.putFileAsync(from: url)
                    await MainActor.run {
                        self.numCompletedUploads += 1
                    }
                }
            }
//            for _ in try await taskGroup {}
        }
    }
}


//private struct UploadSessionSectionView: View {
//    var session: any BulkHealthExporter.ExportSessionProtocol
//    
//    var body: some View {
//        
//    }
//}


//extension HealthSampleTypesCollection {
//    fileprivate var typeErasedSampleTypes: [any AnySampleType] {
//        var retval: [any AnySampleType] = []
//        func imp(_ sampleTypes: some Collection<SampleType<some Any>>) {
//            retval.append(contentsOf: sampleTypes.lazy.map { $0 })
//        }
//        imp(self.quantityTypes)
//        imp(self.correlationTypes)
//        imp(self.categoryTypes)
//        return retval
//    }
//}


extension Sequence {
    func compactMapIntoSet<Result: Hashable>(_ transform: (Element) -> Result?) -> Set<Result> {
        reduce(into: Set<Result>()) { set, element in
            if let element = transform(element) {
                set.insert(element)
            }
        }
    }
}
