//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ModelsR4
import SpeziHealthKit
import SwiftUI


struct PastTimedWalkTestResults: View {
    @MHCFirestoreQuery(fetching: TimedWalkingTestResult.self, timeRange: .ever)
    private var results
    
    var body: some View {
        Form {
            ForEach(results, id: \.id) { result in
                NavigationLink {
                    makeDetailsView(for: result)
                } label: {
                    Text(result.startDate, format: .dateTime)
                }
            }
        }
        .navigationTitle("Timed Walking/Running Tests")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func makeDetailsView(for result: TimedWalkingTestResult) -> some View {
        Form {
            LabeledContent("id", value: result.id.uuidString)
            LabeledContent("Test", value: result.test.displayTitle.localizedString())
            LabeledContent("Start", value: result.startDate, format: .dateTime)
            LabeledContent("End", value: result.endDate, format: .dateTime)
            LabeledContent("Number of Steps", value: result.numberOfSteps, format: .number)
            LabeledContent(
                "Distance",
                value: Measurement<UnitLength>(value: result.distanceCovered, unit: .meters),
                format: .measurement(width: .abbreviated)
            )
        }
    }
}


extension MHCFirestoreQuery {
    init(
        fetching _: TimedWalkingTestResult.Type,
        timeRange: HealthKitQueryTimeRange,
        sorted sortComparator: some SortComparator<TimedWalkingTestResult> = KeyPathComparator(\.startDate, order: .reverse),
        limit: Int? = nil
    ) where Element == TimedWalkingTestResult {
        self.init(
            sampleTypeIdentifier: TimedWalkingTestResult.sampleTypeIdentifier,
            timeRange: timeRange,
            sorted: [sortComparator],
            limit: limit
        ) { resourceProxy in
            resourceProxy
                .get(if: Observation.self)
                .flatMap { TimedWalkingTestResult($0) }
        }
    }
}
