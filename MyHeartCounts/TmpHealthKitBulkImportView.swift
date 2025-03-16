//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziStudy
import SpeziViews
import SwiftUI


struct TmpHealthKitBulkImportView: View {
    @Environment(MyHeartCountsStandard.self)
    private var standard
    
    @HealthKitQuery(.heartRate, timeRange: .last(weeks: 1))
    private var heartRateSamples
    
    @State private var viewState: ViewState = .idle
    @State private var currentUploadIdx = 0
    
    var body: some View {
        Form {
            Section {
                LabeledContent("#heartRateSamples", value: "\(heartRateSamples.count)")
            }
            Section {
                AsyncButton("Upload", state: $viewState) {
                    for sample in heartRateSamples {
                        try await standard.add(sample: sample)
                    }
                }
            }
            Section {
                Text("Progress")
                ProgressView(value: Double(currentUploadIdx) / Double(heartRateSamples.count))
                    .progressViewStyle(.linear)
            }
        }
        .navigationTitle("HealthKit Bulk Upload")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewState != .idle)
        .viewStateAlert(state: $viewState)
    }
}
