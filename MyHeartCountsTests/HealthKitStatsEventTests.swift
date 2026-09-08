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
struct HealthKitStatsEventTests {
    private struct QuantityMetricMapping {
        let metric: HealthStatsMetric
        let sampleType: SampleType<HKQuantitySample>
        let identifier: String
        let unit: HKUnit
    }

    @Test
    func participationQuantityMetricsUseCanonicalUnits() {
        let mappings: [QuantityMetricMapping] = [
            .init(metric: .activeEnergy, sampleType: .activeEnergyBurned, identifier: "active-energy", unit: .largeCalorie()),
            .init(metric: .walkingRunningDistance, sampleType: .distanceWalkingRunning, identifier: "walking-running-distance", unit: .meter()),
            .init(metric: .flightsClimbed, sampleType: .flightsClimbed, identifier: "flights-climbed", unit: .count()),
            .init(metric: .restingHeartRate, sampleType: .restingHeartRate, identifier: "resting-heart-rate", unit: .count() / .minute())
        ]
        for mapping in mappings {
            #expect(HealthStatsMetric(mapping.sampleType) == mapping.metric)
            #expect(mapping.metric.id.rawValue == mapping.identifier)
            #expect(mapping.metric.sampleType.canonicalUnit == mapping.unit)
        }
    }

    @Test
    func workoutWireFormatPreservesActiveDurationAndIdentity() throws {
        let date = Date(timeIntervalSince1970: 1_788_761_600)
        // This in-memory initializer avoids a HealthKit authorization request or a saved test workout.
        let workout = HKWorkout(
            activityType: .running,
            start: date,
            end: date.addingTimeInterval(2700),
            duration: 2400,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: nil
        )
        let entry = HealthKitStatsCalculator.EventSampleEntry(workout: workout)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HealthKitStatsCalculator.EventSampleEntry.self, from: data)
        #expect(decoded.date == workout.startDate)
        #expect(decoded.endDate == workout.endDate)
        #expect(decoded.duration == 2400)
        #expect(decoded.value == 2400)
        #expect(decoded.unit == .second())
        #expect(decoded.activityType == HKWorkoutActivityType.running.rawValue)
        #expect(decoded.provenance.observationID == "healthkit:\(workout.uuid.uuidString.lowercased())")
        #expect(decoded.provenance == HealthKitStatsCalculator.EventSampleEntry(workout: workout).provenance)
        #expect(decoded.provenance.origins.isEmpty)
        let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(fields["start"] == nil)
        #expect(fields["end"] == nil)
        #expect(fields["date"] is String)
        #expect(fields["endDate"] is String)
        let document = HealthKitStatsCalculator.MonthlyStatsDocument(
            metric: .workouts, entriesKey: .samples, entriesBySourceId: [.healthKit: [entry]]
        )
        let stored = try JSONDecoder().decode(StatsDocument.self, from: JSONEncoder().encode(document))
        let snapshot = try StatsStore.Request.workouts(in: .init(date..<workout.endDate.addingTimeInterval(1))).process([stored])
        let workoutSample = try #require(snapshot.elements.first)
        #expect(snapshot.elements.count == 1)
        #expect(snapshot.diagnostics.isEmpty)
        #expect(workoutSample.date == workout.startDate)
        #expect(workoutSample.endDate == workout.endDate)
        #expect(workoutSample.duration == workout.duration)
        #expect(workoutSample.activityType == workout.workoutActivityType)
        #expect(workoutSample.id == entry.provenance.observationID)
    }

    @Test
    func ecgDocumentContainsCountAndTiming() throws {
        let date = Date(timeIntervalSince1970: 1_788_761_600)
        let entry = HealthKitStatsCalculator.EventSampleEntry(
            date: date,
            endDate: date.addingTimeInterval(30),
            provenance: .init(origins: [], observationID: "healthkit:ecg-id")
        )
        let document = HealthKitStatsCalculator.MonthlyStatsDocument(
            metric: .electrocardiograms,
            entriesKey: .samples,
            entriesBySourceId: [.healthKit: [entry]]
        )
        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(
            HealthKitStatsCalculator.MonthlyStatsDocument<HealthKitStatsCalculator.EventSampleEntry>.self,
            from: data
        )
        let result = try #require(decoded.entriesBySourceId[.healthKit]?.first)
        #expect(decoded.version == 0)
        #expect(decoded.metric == .electrocardiograms)
        #expect(decoded.entriesKey == .samples)
        #expect(result.date == date)
        #expect(result.endDate == date.addingTimeInterval(30))
        #expect(result.unit == .count())
        #expect(result.value == 1)
        #expect(result.provenance.observationID == "healthkit:ecg-id")
        #expect(result.duration == nil)
        #expect(result.activityType == nil)
        let stored = try JSONDecoder().decode(StatsDocument.self, from: data)
        let snapshot = try StatsStore.Request.electrocardiograms(in: .init(date..<entry.endDate.addingTimeInterval(1))).process([stored])
        let recording = try #require(snapshot.elements.first)
        #expect(snapshot.elements.count == 1)
        #expect(snapshot.diagnostics.isEmpty)
        #expect(recording.date == entry.date)
        #expect(recording.endDate == entry.endDate)
        #expect(recording.id == entry.provenance.observationID)
    }
}
