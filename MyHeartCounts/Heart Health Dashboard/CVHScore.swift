//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftData
import SwiftUI


@propertyWrapper
@MainActor
struct CustomHealthSampleQuery: DynamicProperty {
    @Query private var samples: [CustomHealthSample]
    
    var wrappedValue: [CustomHealthSample] {
        samples
    }
    
    init(
        _ sampleType: CustomHealthSample.SampleType,
        sortBy sortKeyPath: KeyPath<CustomHealthSample, some Comparable> & Sendable = \.startDate,
        order sortOrder: SortOrder = .forward,
        limit: Int? = nil
    ) {
        let sampleTypeRawValue = sampleType.rawValue
        var descriptor = FetchDescriptor<CustomHealthSample>(
            predicate: #Predicate<CustomHealthSample> { sample in
                sample.sampleTypeRawValue == sampleTypeRawValue
            },
            sortBy: [SortDescriptor(sortKeyPath, order: sortOrder)]
        )
        descriptor.fetchLimit = limit
        _samples = .init(descriptor)
    }
}


@MainActor
@propertyWrapper
struct CVHScore: DynamicProperty {
    protocol ComponentSampleProtocol {
        var timeRange: Range<Date> { get }
    }
    
    @CustomHealthSampleQuery(.dietMEPAScore, sortBy: \.endDate, order: .reverse, limit: 1)
    private var dietScores
    
    @CustomHealthSampleQuery(.bloodLipids, sortBy: \.endDate, order: .reverse, limit: 1)
    private var bloodLipids
    
    @CustomHealthSampleQuery(.nicotineExposure, sortBy: \.endDate, order: .reverse, limit: 1)
    private var nicotineExposure
    
    @HealthKitStatisticsQuery(.appleExerciseTime, aggregatedBy: [.sum], over: .week, timeRange: .last(days: 14))
    private var dailyExerciseTime
    
    @HealthKitQuery(.sleepAnalysis, timeRange: .last(days: 14))
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
    
    /// the composite CVH score, in the range of `0...1`. `nil` if there aren't enough input values to compute a score
    var wrappedValue: Double? {
        let scores: [Double] = [
            dietScore.score,
            physicalExerciseScore.score,
            nicotineExposureScore.score,
            sleepHealthScore.score,
            bodyMassIndexScore.score,
            bloodLipidsScore.score,
            bloodGlucoseScore.score,
            bloodPressureScore.score
        ].compactMap { $0.map { max(0, min(1, $0)) } }
        return scores.count < 5 ? nil : scores.reduce(0, +) / Double(scores.count)
    }
    
    var projectedValue: Self {
        self
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
    
    var nicotineExposureScore: ScoreResult {
        ScoreResult(
            sampleType: .custom(.nicotineExposure),
            sample: nicotineExposure.first,
            value: { CustomHealthSample.NicotineExposureCategoryValues(rawValue: Int($0.value)) },
            definition: .cvhNicotine
        )
    }
    
    var sleepHealthScore: ScoreResult {
        ScoreResult(
            sampleType: .healthKit(.category(.sleepAnalysis)),
            sample: ((try? sleepSamples.splitIntoSleepSessions()) ?? []).last,
            value: { $0.totalTimeAsleep / 60 / 60 },
            definition: .cvhSleep
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
                        systolic: systolic.quantity.doubleValue(for: SampleType.bloodPressureSystolic.displayUnit),
                        diastolic: diastolic.quantity.doubleValue(for: SampleType.bloodPressureDiastolic.displayUnit)
                    )
                } else {
                    nil
                }
            },
            definition: .cvhBloodPressure
        )
        
//        let score = { () -> Double? in
//            guard let correlation = bloodPressure.last,
//                  let systolicSample = correlation.firstSample(ofType: .bloodPressureSystolic),
//                  let diastolicSample = correlation.firstSample(ofType: .bloodPressureDiastolic) else {
//                return nil
//            }
//            let systolic = systolicSample.quantity.doubleValue(for: SampleType.bloodPressureSystolic.displayUnit)
//            let diastolic = diastolicSample.quantity.doubleValue(for: SampleType.bloodPressureDiastolic.displayUnit)
//            if systolic < 100 && diastolic < 80 {
//                return 1
//            } else if systolic < 130 && diastolic < 80 {
//                return 0.75
//            } else if (130..<140).contains(systolic) || (80..<90).contains(diastolic) {
//                return 0.5
//            } else if (140..<160).contains(systolic) || (90..<100).contains(diastolic) {
//                return 0.25
//            } else if systolic >= 160 || diastolic >= 100 {
//                return 0
//            } else {
//                return nil
//            }
//        }()
//        guard let score, let timeRange = bloodPressure.last?.timeRange else {
//            return ScoreResult(sampleType: .healthKit(.correlation(.bloodPressure)), definition: .init(default: 0, mapping: []))
//        }
//        return ScoreResult(
//            sampleType: .healthKit(.correlation(.bloodPressure)),
//            definition: ScoreDefinition(default: 0, mapping: []),
//            score: score,
//            timeRange: timeRange
//        )
    }
}


extension ScoreDefinition {
    static let cvhDiet = ScoreDefinition(default: 0, mapping: [
        .inRange(15...16, score: 1, textualRepresentation: "15 – 16"),
        .inRange(12...14, score: 0.8, textualRepresentation: "15 – 16"),
        .inRange(8...11, score: 0.5, textualRepresentation: "15 – 16"),
        .inRange(4...7, score: 0.25, textualRepresentation: "15 – 16")
    ])
    
    static let cvhPhysicalExercise = ScoreDefinition(default: 0, mapping: [
        .inRange(150..., score: 1),
        .inRange(120..<150, score: 0.9),
        .inRange(90..<120, score: 0.8),
        .inRange(60..<90, score: 0.6),
        .inRange(30..<60, score: 0.4),
        .inRange(1..<30, score: 0.2)
    ])
    
    static let cvhNicotine: ScoreDefinition = {
        typealias NicotineValue = CustomHealthSample.NicotineExposureCategoryValues
        let makeEntry = { (value: NicotineValue, score: Double) -> ScoreDefinition.Element in
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
    
    static let cvhBloodGlucose = ScoreDefinition(default: 0, mapping: []) // TODO!!!
    
    static let cvhBloodPressure = ScoreDefinition(default: 0, mapping: []) // TODO!!!
}


extension QuantitySample: CVHScore.ComponentSampleProtocol {}
extension CustomHealthSample: CVHScore.ComponentSampleProtocol {}

extension HKQuantitySample: CVHScore.ComponentSampleProtocol {}
extension HKCorrelation: CVHScore.ComponentSampleProtocol {}

extension SleepSession: CVHScore.ComponentSampleProtocol {}

extension HKStatistics: CVHScore.ComponentSampleProtocol {
    var timeRange: Range<Date> {
        startDate..<endDate
    }
}
