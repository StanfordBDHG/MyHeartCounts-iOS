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
import Testing


@Suite
struct HealthKitStatsMonthBoundaryTests {
    private typealias StatsMonth = HealthKitStatsCalculator.StatsMonth

    /// Both months must observe a sample spanning midnight so that HealthKit can apportion its aggregate.
    @Test(arguments: ["GMT", "Asia/Kathmandu", "Europe/Berlin"])
    func aggregateQueriesIncludeSamplesCrossingTheMonth(timeZone: String) throws {
        let august = try month(2026, 8, timeZone: timeZone)
        let september = try month(2026, 9, timeZone: timeZone)
        let sample = steps(from: september.range.lowerBound.addingTimeInterval(-120), to: september.range.lowerBound.addingTimeInterval(180))

        for month in [august, september] {
            let descriptor = month.statisticsQuery(
                for: HKQuantityType(.stepCount), options: .cumulativeSum, intervalComponents: DateComponents(hour: 1)
            )
            let predicate = try #require(descriptor.predicate.nsPredicate)
            #expect(predicate.evaluate(with: sample))
            #expect(month.overlappingSamplesPredicate.evaluate(with: sample))
            #expect(descriptor.anchorDate == month.range.lowerBound)
            #expect(descriptor.intervalComponents == DateComponents(hour: 1))
        }
    }

    /// A valid multi-day sample must not be dropped by a fixed one-day padding workaround.
    @Test
    func aggregateQueriesIncludeMultiDaySamples() throws {
        let january = try month(2027, 1)
        // Step samples can span at most four days; this one spans three, centered on New Year.
        let spanningSample = steps(
            from: january.range.lowerBound.addingTimeInterval(-36 * 3600),
            to: january.range.lowerBound.addingTimeInterval(36 * 3600)
        )
        let descriptor = january.statisticsQuery(
            for: HKQuantityType(.stepCount), options: .cumulativeSum, intervalComponents: DateComponents(hour: 1)
        )
        let predicate = try #require(descriptor.predicate.nsPredicate)
        #expect(predicate.evaluate(with: spanningSample))
        #expect(january.overlappingSamplesPredicate.evaluate(with: spanningSample))
        #expect(!predicate.evaluate(with: steps(
            from: january.range.lowerBound.addingTimeInterval(-7200), to: january.range.lowerBound.addingTimeInterval(-3600)
        )))
        #expect(!predicate.evaluate(with: steps(
            from: january.range.upperBound.addingTimeInterval(3600), to: january.range.upperBound.addingTimeInterval(7200)
        )))
    }

    /// An instantaneous sample at the shared boundary belongs only to the new month.
    @Test(arguments: ["GMT", "Asia/Kathmandu", "Europe/Berlin"])
    func aggregateQueriesExcludeTheNextMonthBoundary(timeZone: String) throws {
        let august = try month(2026, 8, timeZone: timeZone)
        let september = try month(2026, 9, timeZone: timeZone)
        let boundary = september.range.lowerBound
        let sample = steps(from: boundary, to: boundary)
        let augustQuery = august.statisticsQuery(
            for: HKQuantityType(.stepCount), options: .cumulativeSum, intervalComponents: DateComponents(hour: 1)
        )
        let septemberQuery = september.statisticsQuery(
            for: HKQuantityType(.stepCount), options: .cumulativeSum, intervalComponents: DateComponents(hour: 1)
        )
        #expect(try !#require(augustQuery.predicate.nsPredicate).evaluate(with: sample))
        #expect(try #require(septemberQuery.predicate.nsPredicate).evaluate(with: sample))
    }

    /// Cumulative and discrete metrics retain their requested statistics and quantity types.
    @Test
    func aggregateQueriesPreserveMetricOptions() throws {
        let march = try month(2026, 3, timeZone: "Europe/Berlin")
        let metrics: [(HKQuantityType, HKStatisticsOptions)] = [
            (HKQuantityType(.appleExerciseTime), .cumulativeSum),
            (HKQuantityType(.heartRate), [.discreteMin, .discreteMax, .discreteAverage])
        ]
        for (type, options) in metrics {
            let descriptor = march.statisticsQuery(for: type, options: options, intervalComponents: DateComponents(hour: 1))
            #expect(descriptor.predicate.sampleType == type)
            #expect(descriptor.options == options)
            #expect(descriptor.anchorDate == march.range.lowerBound)
            #expect(descriptor.intervalComponents == DateComponents(hour: 1))
        }
    }

    /// Individual readings crossing a month boundary are stored exactly once, in their starting month.
    @Test(arguments: ["GMT", "Asia/Kathmandu", "Europe/Berlin"])
    func individualReadingsBelongToTheirStartingMonth(timeZone: String) throws {
        let december = try month(2026, 12, timeZone: timeZone)
        let january = try month(2027, 1, timeZone: timeZone)
        let boundary = january.range.lowerBound
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 73)
        let crossingSample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: quantity,
            start: boundary.addingTimeInterval(-120),
            end: boundary.addingTimeInterval(180)
        )
        let boundarySample = HKQuantitySample(type: HKQuantityType(.bodyMass), quantity: quantity, start: boundary, end: boundary)
        #expect(december.samplesStartingInMonthPredicate.evaluate(with: crossingSample))
        #expect(!january.samplesStartingInMonthPredicate.evaluate(with: crossingSample))
        #expect(!december.samplesStartingInMonthPredicate.evaluate(with: boundarySample))
        #expect(january.samplesStartingInMonthPredicate.evaluate(with: boundarySample))
    }

    /// A blood-pressure reading uses the same single-month ownership as individual quantity readings.
    @Test
    func bloodPressureBelongsToItsStartingMonth() throws {
        let august = try month(2026, 8)
        let september = try month(2026, 9)
        let start = september.range.lowerBound.addingTimeInterval(-120)
        let end = september.range.lowerBound.addingTimeInterval(180)
        let systolic = HKQuantitySample(
            type: HKQuantityType(.bloodPressureSystolic), quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 120), start: start, end: end
        )
        let diastolic = HKQuantitySample(
            type: HKQuantityType(.bloodPressureDiastolic), quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 80), start: start, end: end
        )
        let reading = HKCorrelation(type: HKCorrelationType(.bloodPressure), start: start, end: end, objects: [systolic, diastolic])
        #expect(august.samplesStartingInMonthPredicate.evaluate(with: reading))
        #expect(!september.samplesStartingInMonthPredicate.evaluate(with: reading))
    }

    private func month(_ year: Int, _ month: Int, timeZone: String = "GMT") throws -> StatsMonth {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZone))
        let date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: 1)))
        return try #require(HealthKitStatsCalculator.month(containing: date, calendar: calendar))
    }

    private func steps(from start: Date, to end: Date) -> HKQuantitySample {
        HKQuantitySample(type: HKQuantityType(.stepCount), quantity: HKQuantity(unit: .count(), doubleValue: 100), start: start, end: end)
    }
}
