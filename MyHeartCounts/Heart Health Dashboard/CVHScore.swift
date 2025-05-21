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


@propertyWrapper
@MainActor
struct CVHScore: DynamicProperty {
    protocol ComponentSampleProtocol {
        var timeRange: Range<Date> { get }
    }
    
    struct Score: Sendable, Hashable {
        let sampleType: MHCSampleType
        /// The ``sample`` value, normalized onto a `0...1` range, with `0` denoting "bad" and `1` denoting "good".
        let normalized: Double?
        let timeRange: Range<Date>?
        
        /// - parameter normalize: a closure that normalizes the ``sample`` value onto a `0...1` range, with `0` denoting "bad" and `1` denoting "good".
        fileprivate init<Sample: ComponentSampleProtocol>(sampleType: MHCSampleType, sample: Sample?, normalize: (Sample) -> Double?) {
            self.sampleType = sampleType
            self.timeRange = sample?.timeRange
            self.normalized = sample.flatMap(normalize)
        }
        
        fileprivate init(sampleType: MHCSampleType) {
            self.sampleType = sampleType
            self.timeRange = nil
            self.normalized = nil
        }
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
            dietScore.normalized,
            physicalExerciseScore.normalized,
            nicotineExposureScore.normalized,
            sleepHealthScore.normalized,
            bodyMassIndexScore.normalized,
            bloodLipidsScore.normalized,
            bloodGlucoseScore.normalized,
            bloodPressureScore.normalized
        ].compactMap { $0.map { max(0, min(1, $0)) } }
        return scores.count < 5 ? nil : scores.reduce(0, +) / Double(scores.count)
    }
    
    var projectedValue: Self {
        self
    }
}


extension CVHScore {
    var dietScore: Score {
        Score(sampleType: .custom(.dietMEPAScore), sample: dietScores.first) { sample in
            switch Int(sample.value) {
            case 15...16:
                1
            case 12...14:
                0.8
            case 8...11:
                0.5
            case 4...7:
                0.25
            default:
                0
            }
        }
    }
    
    var physicalExerciseScore: Score {
        Score(sampleType: .healthKit(.quantity(.appleExerciseTime)), sample: dailyExerciseTime.last) { statistics in
            switch statistics.sumQuantity()?.doubleValue(for: .minute()) ?? 0 {
            case 150...:
                1
            case 120..<150:
                0.9
            case 90..<120:
                0.8
            case 60..<90:
                0.6
            case 30..<60:
                0.4
            case 1..<30:
                0.2
            default:
                0
            }
        }
    }
    
    var nicotineExposureScore: Score {
        Score(sampleType: .custom(.nicotineExposure), sample: nicotineExposure.first) { sample in
            switch CustomHealthSample.NicotineExposureCategoryValues(rawValue: Int(sample.value)) {
            case nil:
                nil
            case .neverSmoked:
                1
            case .quitMoreThan5YearsAgo:
                0.75
            case .quitWithin1To5Years:
                0.5
            case .quitWithinLastYearOrIsUsingNDS:
                0.25
            case .activelySmoking:
                0
            }
        }
    }
    
    var sleepHealthScore: Score {
        Score(
            sampleType: .healthKit(.category(.sleepAnalysis)),
            sample: ((try? sleepSamples.splitIntoSleepSessions()) ?? []).last
        ) { (sleepSession: SleepSession) in
            switch sleepSession.totalTimeAsleep / 60 / 60 {
            case 7..<9:
                1
            case 9..<10:
                0.9
            case 6..<7:
                0.7
            case 5..<7, 10...:
                0.4
            case 4..<5:
                0.2
            default:
                0
            }
        }
    }
    
    var bodyMassIndexScore: Score {
        let sampleType = MHCSampleType.healthKit(.quantity(.bodyMassIndex))
        
        let bmiSample = bodyMassIndex.last
        let weightSample = bodyWeight.last
        let heightSample = height.last
        
        let mapping = { (bmi: HKQuantity) -> Double in
            switch bmi.doubleValue(for: SampleType.bodyMassIndex.displayUnit) {
            case ..<25:
                1
            case 25..<30:
                0.7
            case 30..<35:
                0.3
            case 35..<40:
                0.15
            default: // 40...
                0
            }
        }
        
        func calcBMI(weight: HKQuantity, height: HKQuantity) -> Double {
            weight.doubleValue(for: .gramUnit(with: .kilo)) / height.doubleValue(for: .meter())
        }
        
        func makeScore(fromWeight weight: HKQuantitySample, height: HKQuantitySample) -> Score {
            let fakeSample = HKQuantitySample(
                type: SampleType.bodyMassIndex.hkSampleType,
                quantity: HKQuantity(
                    unit: SampleType.bodyMassIndex.displayUnit,
                    doubleValue: calcBMI(weight: weight.quantity, height: height.quantity)
                ),
                start: weight.endDate > height.endDate ? weight.startDate : height.startDate,
                end: weight.endDate > height.endDate ? weight.endDate : height.endDate
            )
            return Score(sampleType: sampleType, sample: fakeSample) { mapping($0.quantity) }
        }
        
        switch (bmiSample, weightSample, heightSample) {
        case (nil, nil, nil), (nil, .some, nil), (nil, nil, .some):
            // if there are no samples, return nil
            print("have nothing, or no BMI and only one of weight/height")
            return .init(sampleType: sampleType)
        case (.some(let sample), nil, nil), (.some(let sample), .some, nil), (.some(let sample), nil, .some):
            // if we have a BMI sample, but not also a weight AND height sample, return the BMI sample
            print("have BMI and one of weight/height")
            return Score(sampleType: sampleType, sample: sample) { mapping($0.quantity) }
        case let (nil, .some(weight), .some(height)):
            print("have nothing, but weight and height")
            // if we have no BMI sample, but weight and height samples, compute BMI from that
            guard weight.endDate.timeIntervalSinceNow < TimeConstants.year / 2 else {
                // if the weight is from too long ago, we don't use it.
                // we don't have the same check for height, since that doesn't flucuate as much as weight, for adults.
                return .init(sampleType: sampleType)
            }
            return makeScore(fromWeight: weight, height: height)
        case let (.some(bmi), .some(weight), .some(height)):
            print("have BMI and weight and height")
            if bmi.endDate > weight.endDate {
                // if the BMI sample is newer, use that
                return Score(sampleType: sampleType, sample: bmi) { mapping($0.quantity) }
            } else {
                return makeScore(fromWeight: weight, height: height)
            }
        }
    }
    
    
    var bloodLipidsScore: Score {
        Score(sampleType: .custom(.bloodLipids), sample: bloodLipids.first) { sample in
            switch sample.value {
            case ..<130:
                1
            case 130..<160:
                0.6
            case 160..<190:
                0.4
            case 190..<220:
                0.2
            default: // 220...
                0
            }
        }
    }
    
    var bloodGlucoseScore: Score {
        Score(sampleType: .healthKit(.quantity(.bloodGlucose)), sample: bloodGlucose.last) { sample in
            0.5 // TODO!
        }
    }
    
    var bloodPressureScore: Score {
        Score(sampleType: .healthKit(.correlation(.bloodPressure)), sample: bloodPressure.last) { correlation in
            guard let systolicSample = correlation.firstSample(ofType: .bloodPressureSystolic),
                  let diastolicSample = correlation.firstSample(ofType: .bloodPressureDiastolic) else {
                return nil
            }
            let systolic = systolicSample.quantity.doubleValue(for: SampleType.bloodPressureSystolic.displayUnit)
            let diastolic = diastolicSample.quantity.doubleValue(for: SampleType.bloodPressureDiastolic.displayUnit)
            if systolic < 100 && diastolic < 80 {
                return 1
            } else if systolic < 130 && diastolic < 80 {
                return 0.75
            } else if (130..<140).contains(systolic) || (80..<90).contains(diastolic) {
                return 0.5
            } else if (140..<160).contains(systolic) || (90..<100).contains(diastolic) {
                return 0.25
            } else if systolic >= 160 || diastolic >= 100 {
                return 0
            } else {
                return nil
            }
        }
    }
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
