//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SpeziAccount
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


@MainActor
@propertyWrapper
struct CVHScore: DynamicProperty {
    protocol ComponentSampleProtocol {
        var timeRange: Range<Date> { get }
    }
    
    enum PreferredExerciseMetric {
        case exerciseMinutes
        case stepCount
    }
    
    /// A time range that fetches all data over the last 2 weeks, excluding today.
    /// We use this range for metrics where the score is derived from the daily total, as opposed to the most recent value,
    /// in order to prevent displaying scores derived from incomplete data (eg: if you open the app at noon and only have a small number of
    /// steps / exercise minutes tracked for the day so far).
    private static let queryTimeRangeLastFullDayInLast2Weeks: HealthKitQueryTimeRange = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let twoWeeksAgo = cal.date(byAdding: .weekOfYear, value: -2, to: today) else {
            preconditionFailure("Unable to determine start date")
        }
        return .init(twoWeeksAgo..<today)
    }()
    
    @State private(set) var preferredExerciseMetric: PreferredExerciseMetric = .exerciseMinutes
    
    @MHCFirestoreQuery(sampleType: .dietMEPAScore, timeRange: .last(months: 2))
    private var dietScores
    
    @MHCFirestoreQuery(sampleType: .bloodLipids, timeRange: .last(months: 2))
    private var bloodLipids
    
    @MHCFirestoreQuery(sampleType: .nicotineExposure, timeRange: .last(months: 2))
    private var nicotineExposure
    
    @HealthKitStatisticsQuery(.appleExerciseTime, aggregatedBy: [.sum], over: .day, timeRange: Self.queryTimeRangeLastFullDayInLast2Weeks)
    private var dailyExerciseTime
    
    @HealthKitStatisticsQuery(.stepCount, aggregatedBy: [.sum], over: .day, timeRange: Self.queryTimeRangeLastFullDayInLast2Weeks)
    private var dailyStepCount
    
    @HealthKitQuery(.sleepAnalysis, timeRange: .last(days: 14), source: .appleHealthSystem)
    private var sleepSamples
    
    @HealthKitQuery(.bodyMassIndex, timeRange: .last(days: 14))
    private var bodyMassIndex
    
    @HealthKitQuery(.bodyMass, timeRange: .last(months: 3))
    private var bodyWeight
    
    @HealthKitQuery(.height, timeRange: .last(years: 5))
    private var height
    
    @HealthKitQuery(.bloodGlucose, timeRange: .last(days: 14))
    private var bloodGlucose
    
    @HealthKitQuery(.bloodPressure, timeRange: .last(months: 3))
    private var bloodPressure
    
    @State private var lastSeenSleepSamples: [HKCategorySample] = []
    @State private(set) var sleepHealthScore = ScoreResult(sampleType: .healthKit(.category(.sleepAnalysis)), definition: .cvhSleep)
    
    /// the composite CVH score, in the range of `0...1`. `nil` if there aren't enough input values to compute a score
    var wrappedValue: Double? {
        _ = sleepSamples
        Task {
            await updateSleepScore()
        }
        let scores: [ScoreResult] = Array {
            dietScore
            switch preferredExerciseMetric {
            case .exerciseMinutes:
                physicalExerciseScore
            case .stepCount:
                stepCountScore
            }
            nicotineExposureScore
            sleepHealthScore
            bodyMassIndexScore
            bloodLipidsScore
            bloodGlucoseScore
            bloodPressureScore
        }
        let scoreResults = scores.compactMap { $0.score.map { $0.clamped(to: 0...1) } }
        return scoreResults.count < 5 ? nil : scoreResults.reduce(0, +) / Double(scoreResults.count)
    }
    
    var projectedValue: Self {
        self
    }
    
    nonisolated func update() {
        Task {
            await updateSleepScore()
        }
    }
    
    @concurrent
    private func updateSleepScore() async {
        let sleepSamples = await MainActor.run { () -> [HKCategorySample] in
            guard !lastSeenSleepSamples.elementsEqual(self.sleepSamples) else {
                // if we don't need an update, we return an empty array here, which will cause the code below to return early.
                return []
            }
            // this ensures that any subsequent calls (including while the computation below is running) will return early, unless data actually changed.
            let sleepSamples = Array(self.sleepSamples)
            self.lastSeenSleepSamples = sleepSamples
            return sleepSamples
        }
        guard !sleepSamples.isEmpty else {
            return
        }
        dispatchPrecondition(condition: .notOnQueue(.main))
        let sleepSessions = (try? sleepSamples.splitIntoSleepSessions()) ?? []
        let score = ScoreResult(
            sampleType: .healthKit(.category(.sleepAnalysis)),
            sample: sleepSessions.last,
            value: { $0.totalTimeSpentAsleep / 60 / 60 },
            definition: .cvhSleep
        )
        await MainActor.run {
            self.sleepHealthScore = score
        }
    }
}


extension CVHScore {
    var dietScore: ScoreResult {
        ScoreResult(
            sampleType: .custom(.dietMEPAScore),
            sample: dietScores.first,
            value: \.value,
            definition: .cvhDiet
        )
    }
    
    var physicalExerciseScore: ScoreResult {
        ScoreResult(
            sampleType: .healthKit(.quantity(.appleExerciseTime)),
            sample: dailyExerciseTime.last,
            value: { $0.sumQuantity()?.doubleValue(for: .minute()) ?? 0 },
            definition: .cvhPhysicalExercise
        )
    }
    
    var stepCountScore: ScoreResult {
        ScoreResult(
            sampleType: .healthKit(.quantity(.appleExerciseTime)),
            sample: dailyStepCount.last,
            value: { $0.sumQuantity()?.doubleValue(for: .minute()) ?? 0 },
            definition: .cvhPhysicalExercise
        )
    }
    
    var nicotineExposureScore: ScoreResult {
        ScoreResult(
            sampleType: .custom(.nicotineExposure),
            sample: nicotineExposure.first,
            value: { NicotineExposureCategoryValues(rawValue: Int($0.value)) },
            definition: .cvhNicotine
        )
    }
    
    var bodyMassIndexScore: ScoreResult {
        let sampleType = MHCSampleType.healthKit(.quantity(.bodyMassIndex))
        let bmiSample = bodyMassIndex.last
        let weightSample = bodyWeight.last
        let heightSample = height.last
        func calcBMI(weight: HKQuantity, height: HKQuantity) -> Double {
            weight.doubleValue(for: .gramUnit(with: .kilo)) / pow(height.doubleValue(for: .meter()), 2)
        }
        func makeScore(bmiSample: HKQuantitySample) -> ScoreResult {
            ScoreResult(
                sampleType: sampleType,
                sample: bmiSample,
                value: { $0.quantity.doubleValue(for: SampleType.bodyMassIndex.displayUnit) },
                definition: .cvhBMI
            )
        }
        func makeScore(fromWeight weight: HKQuantitySample, height: HKQuantitySample) -> ScoreResult {
            let fakeSample = HKQuantitySample(
                type: SampleType.bodyMassIndex.hkSampleType,
                quantity: HKQuantity(
                    unit: SampleType.bodyMassIndex.displayUnit,
                    doubleValue: calcBMI(weight: weight.quantity, height: height.quantity)
                ),
                start: weight.endDate > height.endDate ? weight.startDate : height.startDate,
                end: weight.endDate > height.endDate ? weight.endDate : height.endDate
            )
            return makeScore(bmiSample: fakeSample)
        }
        switch (bmiSample, weightSample, heightSample) {
        case (nil, nil, nil), (nil, .some, nil), (nil, nil, .some):
            // if there are no samples, return nil
            return .init(sampleType: sampleType, definition: .cvhBMI)
        case (.some(let sample), nil, nil), (.some(let sample), .some, nil), (.some(let sample), nil, .some):
            // if we have a BMI sample, but not also a weight AND height sample, return the BMI sample
            return makeScore(bmiSample: sample)
        case let (nil, .some(weight), .some(height)):
            // if we have no BMI sample, but weight and height samples, compute BMI from that
            guard weight.endDate.timeIntervalSinceNow < TimeConstants.year / 2 else {
                // if the weight is from too long ago, we don't use it.
                // we don't have the same check for height, since that doesn't flucuate as much as weight, for adults.
                return .init(sampleType: sampleType, definition: .cvhBMI)
            }
            return makeScore(fromWeight: weight, height: height)
        case let (.some(bmi), .some(weight), .some(height)):
            if bmi.endDate > weight.endDate {
                // if the BMI sample is newer, use that
                return makeScore(bmiSample: bmi)
            } else {
                return makeScore(fromWeight: weight, height: height)
            }
        }
    }
    
    var bloodLipidsScore: ScoreResult {
        ScoreResult(
            sampleType: .custom(.bloodLipids),
            sample: bloodLipids.first,
            value: \.value,
            definition: .cvhBloodLipids
        )
    }
    
    var bloodGlucoseScore: ScoreResult {
        ScoreResult(
            sampleType: .healthKit(.quantity(.bloodGlucose)),
            sample: bloodGlucose.last,
            value: { $0.quantity.doubleValue(for: SampleType.bloodGlucose.displayUnit) },
            definition: .cvhBloodGlucose
        )
    }
    
    var bloodPressureScore: ScoreResult {
        ScoreResult(
            sampleType: .healthKit(.correlation(.bloodPressure)),
            sample: bloodPressure.last,
            value: { correlation in
                if let systolic = correlation.firstSample(ofType: .bloodPressureSystolic),
                   let diastolic = correlation.firstSample(ofType: .bloodPressureDiastolic) {
                    BloodPressureMeasurement(
                        systolic: Int(systolic.quantity.doubleValue(for: SampleType.bloodPressureSystolic.displayUnit)),
                        diastolic: Int(diastolic.quantity.doubleValue(for: SampleType.bloodPressureDiastolic.displayUnit))
                    )
                } else {
                    nil
                }
            },
            definition: .cvhBloodPressure
        )
    }
}


extension ScoreDefinition {
    static let cvhDiet = ScoreDefinition(default: 0, mapping: [
        .inRange(17...21, score: 1, textualRepresentation: "17 – 21"),
        .inRange(14...16, score: 0.85, textualRepresentation: "14 – 16"),
        .inRange(11...14, score: 0.7, textualRepresentation: "11 – 14"),
        .inRange(8...10, score: 0.5, textualRepresentation: "8 – 10"),
        .inRange(5...7, score: 0.25, textualRepresentation: "5 – 7"),
        .inRange(...7, score: 0, textualRepresentation: "< 7")
    ])
    
    static let cvhPhysicalExercise = ScoreDefinition(default: 0, mapping: [
        .inRange(150..., score: 1),
        .inRange(120..<150, score: 0.9),
        .inRange(90..<120, score: 0.8),
        .inRange(60..<90, score: 0.6),
        .inRange(30..<60, score: 0.4),
        .inRange(1..<30, score: 0.2)
    ])
    
    static let cvhStepCount = ScoreDefinition(default: 0, mapping: [
        .inRange(10_000..., score: 1),
        .inRange(120..<150, score: 0.9),
        .inRange(90..<120, score: 0.8),
        .inRange(60..<90, score: 0.6),
        .inRange(30..<60, score: 0.4),
        .inRange(1..<2000, score: 0.2)
    ])
    
    static let cvhNicotine: ScoreDefinition = {
        let makeEntry = { (value: NicotineExposureCategoryValues, score: Double) -> ScoreDefinition.Element in
            ScoreDefinition.Element.equal(to: value, score: score, textualRepresentation: String(localized: value.shortDisplayTitle))
        }
        return ScoreDefinition(default: 0, mapping: [
            makeEntry(.neverSmoked, 1),
            makeEntry(.quitMoreThan5YearsAgo, 0.75),
            makeEntry(.quitWithin1To5Years, 0.5),
            makeEntry(.quitWithinLastYearOrIsUsingNDS, 0.25),
            makeEntry(.activelySmoking, 0)
        ])
    }()
    
    static let cvhSleep = ScoreDefinition(default: 0, mapping: [
        .inRange(7..<9, score: 1, textualRepresentation: "7 to 9 hours"),
        .inRange(9..<10, score: 0.9, textualRepresentation: "9 to 10 hours"),
        .inRange(6..<7, score: 0.7, textualRepresentation: "6 to 7 hours"),
        .inRange(5..<6, score: 0.4, textualRepresentation: "5 to 6 hours"),
        .inRange(10..., score: 0.4, textualRepresentation: "10+ hours"),
        .inRange(4..<5, score: 0.2, textualRepresentation: "4 to 5 hours")
    ])
    
    static let cvhBMI = ScoreDefinition(default: 0, mapping: [
        .inRange(..<25, score: 1),
        .inRange(25..<30, score: 0.7),
        .inRange(30..<35, score: 0.3),
        .inRange(35..<40, score: 0.15),
        .inRange(40..., score: 0)
    ])
    
    static let cvhBloodLipids = ScoreDefinition(default: 0, mapping: [
        .inRange(..<130, score: 1),
        .inRange(130..<160, score: 0.6),
        .inRange(160..<190, score: 0.4),
        .inRange(190..<220, score: 0.2),
        .inRange(220..., score: 0)
    ])
    
    static let cvhBloodGlucose = ScoreDefinition(default: 0, mapping: [
        .inRange(..<5.7, score: 1),
        .inRange(5.7..<6.5, score: 0.75),
        .inRange(6.5..<7, score: 0.5),
        .inRange(7..<8, score: 0.3),
        .inRange(8..<9, score: 0.2),
        .inRange(9..<10, score: 0.1),
        .inRange(10..., score: 0)
    ])
    
    static let cvhBloodPressure = ScoreDefinition(
        default: 0,
        // ideally we'd simply put the explanation directly into the ScoreDefinition, and have it work in a way that
        // the UI gets created based on that; but for the time being we simply have this ScoreDefinition hardcoded.
        textualRepresentation: ""
    ) { (measurement: BloodPressureMeasurement) in
        let systolicScore: Double = switch measurement.systolic as Int {
        case ..<120: 0.75
        case 120...129: 0.65
        case 130...139: 0.5
        case 140...159: 0.25
        case 160...: 0
        default: 0 // unreachable
        }
        let diastolicScore: Double = switch measurement.diastolic as Int {
        case ..<80: 0.25
        case 80...89: 0.15
        case 90...99: 0.05
        case 100...: 0
        default: 0 // unreachable
        }
        return systolicScore + diastolicScore
    }
}


extension QuantitySample: CVHScore.ComponentSampleProtocol {}

extension HKQuantitySample: CVHScore.ComponentSampleProtocol {}
extension HKCorrelation: CVHScore.ComponentSampleProtocol {}

extension SleepSession: CVHScore.ComponentSampleProtocol {}

extension HKStatistics: CVHScore.ComponentSampleProtocol {
    var timeRange: Range<Date> {
        startDate..<endDate
    }
}


extension HealthKit.SourceFilter {
    static let appleHealthSystem = Self.bundleId(beginsWith: "com.apple.health")
}
