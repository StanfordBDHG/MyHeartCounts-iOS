//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKitBulkExport
import SpeziSensorKit
import SwiftUI


struct DataProcessingDebugView: View {
    // swiftlint:disable attributes
    @Environment(HistoricalHealthSamplesExportManager.self) private var historicalHealthDataExportMgr
    @Environment(ManagedFileUpload.self) private var managedFileUpload
    @Environment(SensorKitDataFetcher.self) private var sensorKitFetcher
    // swiftlint:enable attributes
    
    var body: some View {
        Form { // swiftlint:disable:this closure_body_length
            Section("HealthKit") {
                LabeledContent("Historical Fetch", value: historicalHealthDataExportMgr.session?.state.displayTitle ?? "n/a")
                if let progress = historicalHealthDataExportMgr.exportProgress {
                    ProgressView("Historical Fetch Progress", value: progress.completion)
                }
                ForEach([ManagedFileUpload.Category.historicalHealthUpload, .liveHealthUpload]) { category in
                    if let progress = managedFileUpload.progressByCategory[category] {
                        ProgressView(progress)
                    }
                }
            }
            if !sensorKitFetcher.activeActivities.isEmpty {
                Section("SensorKit (Fetch)") {
                    let activities = sensorKitFetcher.activeActivities.sorted(using: KeyPathComparator(\.sensor.displayName))
                    ForEach(activities) { activity in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(activity.sensor.displayName)
                                if let timeRange = activity.timeRange {
                                    Text(timeRange.displayText(using: .current))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !activity.message.isEmpty {
                                    Text(activity.message)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            }
            let progresss = managedFileUpload.progressByCategory.compactMap {
                $0.id.contains("SensorKit") ? $1 : nil
            }
            if !progresss.isEmpty {
                Section("SensorKit (Upload)") {
                    ForEach(Array(progresss.indices), id: \.self) { idx in
                        ProgressView(progresss[idx])
                    }
                }
            }
        }
    }
}
