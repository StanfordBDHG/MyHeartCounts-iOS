//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ModelsR4
import SFSafeSymbols
import SpeziHealthKit
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct PastTimedWalkTestResults: View {
    @MHCFirestoreQuery(fetching: TimedWalkingTestResult.self, timeRange: .ever)
    private var pastTests
    
    @State private var activeTest: TimedWalkingTestConfiguration?
    
    var body: some View {
        Form {
            Section("New Test") {
                newTestSection
            }
            if !pastTests.isEmpty {
                Section("Past Tests") {
                    ForEach(pastTests, id: \.id) { (result: TimedWalkingTestResult) in
                        NavigationLink {
                            makeDetailsView(for: result)
                        } label: {
                            LabeledContent(result.test.displayTitle, value: result.startDate, format: .dateTime)
                        }
                    }
                }
            }
        }
        .navigationTitle("Timed Walking/Running Tests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                DismissButton()
            }
        }
        .sheet(item: $activeTest, id: \.self) { test in
            TimedWalkingTestView(test)
        }
    }
    
    @ViewBuilder private var newTestSection: some View {
        let tests: [TimedWalkingTestConfiguration] = [
            .sixMinuteWalkTest,
            .twelveMinuteRunTest,
            .init(duration: .seconds(1), kind: .walking)
        ]
        ForEach(tests, id: \.self) { test in
            Button {
                activeTest = test
            } label: {
                Label {
                    Text(test.displayTitle)
                } icon: {
                    Image(systemSymbol: test.kind.symbol)
                        .accessibilityHidden(true)
                }
            }
        }
    }
    
    @ViewBuilder
    private func makeDetailsView(for result: TimedWalkingTestResult) -> some View {
        Form {
            LabeledContent("Start", value: result.startDate, format: .dateTime)
            LabeledContent("End", value: result.endDate, format: .dateTime)
            LabeledContent("Number of Steps", value: result.numberOfSteps, format: .number)
            LabeledContent(
                "Distance",
                value: Measurement<UnitLength>(value: result.distanceCovered, unit: .meters),
                format: .measurement(width: .abbreviated)
            )
        }
        .navigationTitle(result.test.displayTitle.localizedString())
        .navigationBarTitleDisplayMode(.inline)
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
