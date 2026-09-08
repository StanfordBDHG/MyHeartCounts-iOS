//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
@testable import MyHeartCounts
import SpeziHealthKit
import Testing


@Suite
struct StatsEventProcessingTests {
    private let healthKit = "com.apple.HealthKit"
    private var range: Range<Date> { date(0)..<date(24) }

    @Test
    func workoutsRetainActiveDurationAndDeduplicateMirrorsAcrossMonths() throws {
        let workout = workout(id: "shared", hour: 1)
        let output = try StatsStore.Request.workouts(in: .init(range)).process([
            document(.workouts, [healthKit: [workout]]),
            document(.workouts, ["mirror": [workout], healthKit: [self.workout(id: "second", hour: 3)]])
        ])
        #expect(output.elements.map(\.id) == ["shared", "second"])
        #expect(output.elements.first?.duration == 900)
        #expect(output.elements.first?.endDate == date(2))
        #expect(output.elements.first?.activityType == .walking)
        #expect(output.contributingSourceIDs == [healthKit])
    }

    @Test
    func recordingsUseHalfOpenStartDateBoundsAndPreserveEndDate() throws {
        var incomplete = ecg(id: "incomplete", hour: 23)
        incomplete.endDate = date(25).ISO8601Format()
        let recordings = [ecg(id: "before", hour: -1), ecg(id: "inside", hour: 0), ecg(id: "after", hour: 24), incomplete]
        let output = try StatsStore.Request.electrocardiograms(in: .init(range)).process([
            document(.electrocardiograms, [healthKit: recordings])
        ])
        #expect(output.elements.map(\.id) == ["inside"])
        #expect(output.elements.first?.endDate == date(0).addingTimeInterval(30))
    }

    @Test
    func independentRecordingsAtTheSameInstantAreRetainedButUnknownCopiesCompete() throws {
        var first = ecg(id: "first", hour: 2)
        var second = ecg(id: "second", hour: 2)
        let unknown = document(.electrocardiograms, [healthKit: [first], "other": [second]])
        let preferred = try StatsStore.Request.electrocardiograms(in: .init(range)).process([unknown])
        #expect(preferred.elements.map(\.id) == ["first"])
        #expect(preferred.diagnostics.count == 1)
        #expect(throws: StatsStore.Processor.Error.self) {
            try StatsStore.Request.electrocardiograms(in: .init(range), sourcePolicy: .mergeCompatible).process([unknown])
        }
        first.provenance = .init(origins: ["device-a"], observationID: "first")
        second.provenance = .init(origins: ["device-b"], observationID: "second")
        let independent = document(.electrocardiograms, [healthKit: [first], "other": [second]])
        let merged = try StatsStore.Request.electrocardiograms(in: .init(range)).process([independent])
        #expect(Set(merged.elements.map(\.id)) == ["first", "second"])
        let only = try StatsStore.Request.electrocardiograms(in: .init(range), sourcePolicy: .only("other")).process([independent])
        #expect(only.elements.map(\.id) == ["second"])
    }

    @Test
    func malformedEventsAreDiagnosedWithoutDiscardingValidEntries() throws {
        var missingIdentity = workout(id: "no-identity", hour: 0)
        missingIdentity.provenance = nil
        var inconsistentDuration = workout(id: "duration", hour: 1)
        inconsistentDuration.duration = 800
        var invalidEnd = workout(id: "end", hour: 2)
        invalidEnd.endDate = date(1).ISO8601Format()
        var invalidUnit = workout(id: "unit", hour: 3)
        invalidUnit = .init(
            date: invalidUnit.date,
            value: 900,
            unit: "kg",
            provenance: invalidUnit.provenance,
            endDate: invalidUnit.endDate,
            duration: 900,
            activityType: HKWorkoutActivityType.walking.rawValue
        )
        let output = try StatsStore.Request.workouts(in: .init(range)).process([
            document(.workouts, [healthKit: [missingIdentity, inconsistentDuration, invalidEnd, invalidUnit, workout(id: "valid", hour: 4)]])
        ])
        #expect(output.elements.map(\.id) == ["valid"])
        #expect(output.diagnostics == [.malformedEntryCount(4)])
    }

    private func date(_ hour: Int) -> Date {
        Date(timeIntervalSince1970: 1_788_761_600 + Double(hour) * 3600)
    }

    private func document(_ metric: HealthKitStatsCalculator.MetricID, _ sources: [String: [StatsDocument.Entry]]) -> StatsDocument {
        StatsDocument(metric: metric.rawValue, entriesBySourceId: sources)
    }

    private func workout(id: String, hour: Int) -> StatsDocument.Entry {
        .init(
            date: date(hour).ISO8601Format(),
            value: 900,
            unit: "s",
            provenance: .init(origins: [], observationID: id),
            endDate: date(hour + 1).ISO8601Format(),
            duration: 900,
            activityType: HKWorkoutActivityType.walking.rawValue
        )
    }

    private func ecg(id: String, hour: Int) -> StatsDocument.Entry {
        .init(
            date: date(hour).ISO8601Format(),
            value: 1,
            unit: "count",
            provenance: .init(origins: [], observationID: id),
            endDate: date(hour).addingTimeInterval(30).ISO8601Format()
        )
    }
}
