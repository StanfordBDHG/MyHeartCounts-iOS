//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziAccount
import SpeziFoundation
import SpeziHealthKitBulkExport
import SpeziStudy
import SpeziViews
import SwiftUI


/// A `View` that allows debugging and controling the ``HealthImporter``.
///
/// Primarily intended for internal use.
struct HealthImporterControlView: View {
    @Environment(HistoricalHealthSamplesExportManager.self)
    private var exportManager
    
    @State private var viewState: ViewState = .idle
    
    
    var body: some View {
        Form {
            actionsSection
            AsyncButton("Delete&Reset Session", state: $viewState) {
                try exportManager.fullyResetSession()
            }
            if let session = exportManager.session {
                section(for: session)
            }
        }
        .navigationTitle("Bulk Export Manager")
        .navigationBarTitleDisplayMode(.inline)
        .viewStateAlert(state: $viewState)
    }
    
    @ViewBuilder private var actionsSection: some View {
        Section {
            AsyncButton("Delete ~/HealthKitUploads/*", state: $viewState) {
                let fileManager = FileManager.default
                for url in (try? fileManager.contentsOfDirectory(at: .scheduledHealthKitUploads, includingPropertiesForKeys: nil)) ?? [] {
                    try fileManager.removeItem(at: url)
                }
            }
        }
    }
    
    @ViewBuilder
    private func section(for session: any BulkExportSession) -> some View {
        Section {
            Text(session.sessionId.rawValue)
                .monospaced()
            LabeledContent("State") {
                Text(session.state.displayTitle)
            }
            if let progress = session.progress {
                ProgressView(progress)
            }
        }
    }
}


extension Sequence {
    func compactMapIntoSet<Result: Hashable>(_ transform: (Element) -> Result?) -> Set<Result> {
        reduce(into: Set<Result>()) { set, element in
            if let element = transform(element) {
                set.insert(element)
            }
        }
    }
}

extension BulkExportSessionState {
    fileprivate var displayTitle: String {
        switch self {
        case .paused:
            "paused"
        case .running:
            "running"
        case .completed:
            "completed"
        case .terminated:
            "terminated"
        }
    }
}
