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
    
    @HealthKitQuery(.activeEnergyBurned, timeRange: .last(weeks: 4))
    private var samples
    
    @State private var viewState: ViewState = .idle
    @State private var currentUploadIdx = 0
    
    var body: some View {
        Form {
            Section {
                LabeledContent("#samples", value: "\(samples.count)")
            }
            Section {
                AsyncButton("Upload", state: $viewState) {
                    currentUploadIdx = 0
                    for sample in samples {
                        await standard.handleNewSamples(CollectionOfOne(sample), ofType: $samples.sampleType)
                        currentUploadIdx += 1
                    }
                }
            }
            Section {
                Text("Progress")
                ProgressView(value: Double(currentUploadIdx) / Double(samples.count))
                    .progressViewStyle(.linear)
            }
        }
        .navigationTitle("HealthKit Bulk Upload")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewState != .idle)
        .viewStateAlert(state: $viewState)
    }
}
