//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import MyHeartCountsShared


extension HealthKitStatsCalculator {
    /// An identified event, stored in the month containing its start date.
    /// `endDate` describes the event without turning it into a quantity-aggregation bucket.
    struct EventSampleEntry: Codable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case date, endDate, unit, value, duration, activityType, provenance
        }

        let date: Date
        let endDate: Date
        let unit: HKUnit
        let value: Double
        let duration: TimeInterval?
        let activityType: UInt?
        let provenance: StatsDocument.Provenance

        init(workout: HKWorkout) {
            date = workout.startDate
            endDate = workout.endDate
            unit = .second()
            value = workout.duration
            duration = workout.duration
            activityType = workout.workoutActivityType.rawValue
            provenance = HealthKitStatsCalculator.provenance(for: workout)
        }

        init(electrocardiogram: HKElectrocardiogram) {
            self.init(
                date: electrocardiogram.startDate,
                endDate: electrocardiogram.endDate,
                provenance: HealthKitStatsCalculator.provenance(for: electrocardiogram)
            )
        }

        /// The ECG summary contains identity and timing, without the waveform or classification.
        init(date: Date, endDate: Date, provenance: StatsDocument.Provenance) {
            self.date = date
            self.endDate = endDate
            unit = .count()
            value = 1
            duration = nil
            activityType = nil
            self.provenance = provenance
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try StatsWireFormat.parseDate(container.decode(String.self, forKey: .date))
            endDate = try StatsWireFormat.parseDate(container.decode(String.self, forKey: .endDate))
            unit = try container.decode(HKUnit.self, forKey: .unit)
            value = try container.decode(Double.self, forKey: .value)
            duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
            activityType = try container.decodeIfPresent(UInt.self, forKey: .activityType)
            provenance = try container.decode(StatsDocument.Provenance.self, forKey: .provenance)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(date.formatted(StatsWireFormat.dateFormat), forKey: .date)
            try container.encode(endDate.formatted(StatsWireFormat.dateFormat), forKey: .endDate)
            try container.encode(unit, forKey: .unit)
            try container.encode(value, forKey: .value)
            try container.encodeIfPresent(duration, forKey: .duration)
            try container.encodeIfPresent(activityType, forKey: .activityType)
            try container.encode(provenance, forKey: .provenance)
        }
    }
}
