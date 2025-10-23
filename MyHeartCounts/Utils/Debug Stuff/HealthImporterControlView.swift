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
    
    private let fileManager = FileManager.default
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        Form {
            AsyncButton("Delete&Reset Session", state: $viewState) {
                try await exportManager.fullyResetSession()
            }
            if let session = exportManager.session {
                section(for: session)
            }
        }
        .navigationTitle("Bulk Export Manager")
        .navigationBarTitleDisplayMode(.inline)
        .viewStateAlert(state: $viewState)
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


extension BulkExportSessionState {
    var displayTitle: String {
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
