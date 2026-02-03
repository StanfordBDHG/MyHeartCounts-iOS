//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable force_unwrapping function_body_length attributes
// SAFETY: only used when taking screenshots; not used in production

import FirebaseFirestore
import Foundation
import MyHeartCountsShared
import Spezi
import SpeziFoundation
import SpeziHealthKit


@Observable
@MainActor
final class DemoSetup: Module, EnvironmentAccessible, Sendable { // swiftlint:disable:this type_body_length
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @StandardActor private var standard: MyHeartCountsStandard
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    
    @ObservationIgnored private let cal = Calendar.current
    
    @ObservationIgnored private let healthKitAccessRequirements = HealthKit.DataAccessRequirements(readAndWrite: [
        SampleType.sleepAnalysis,
        SampleType.stepCount,
        SampleType.distanceWalkingRunning,
        SampleType.workout,
        SampleType.bloodPressureSystolic,
        SampleType.bloodPressureDiastolic,
        SampleType.bloodGlucose,
        SampleType.bodyMassIndex
    ] as [any AnySampleType])
    
    
    private func assertCanAddDemoData() throws {
        guard ProcessInfo.isRunningInSimulator && ProcessInfo.isBeingUITested && FeatureFlags.isTakingDemoScreenshots else {
            throw NSError(localizedDescription: "Demo setup not available!")
        }
    }
    
    func addDemoData() async throws {
        try assertCanAddDemoData()
        try await removeAllDemoHealthKitData()
        
        try await healthKit.askForAuthorization(for: healthKitAccessRequirements)
        
        try await addCustomSurveysHealthDashboardData()
        try await addDemoSleepSamples()
        try await addStepsData()
        try await addBloodPressureSamples()
        
        try await addCustomHealthSample(QuantitySample(
            id: UUID(),
            sampleType: .custom(.bloodLipids),
            unit: CustomQuantitySampleType.bloodLipids.displayUnit,
            value: 130,
            date: cal.date(bySettingHour: 19, minute: 50, second: 0, of: cal.startOfPrevDay(for: .now))!
        ))
        try await healthKit.save(HKQuantitySample(
            type: SampleType.bloodGlucose.hkSampleType,
            quantity: HKQuantity(unit: SampleType.bloodGlucose.displayUnit, doubleValue: 91),
            start: cal.date(bySettingHour: 9, minute: 12, second: 0, of: cal.date(byAdding: .day, value: -5, to: .now)!)!,
            end: cal.date(bySettingHour: 9, minute: 12, second: 0, of: cal.date(byAdding: .day, value: -5, to: .now)!)!
        ))
        try await healthKit.save(HKQuantitySample(
            type: SampleType.bodyMassIndex.hkSampleType,
            quantity: HKQuantity(unit: SampleType.bodyMassIndex.displayUnit, doubleValue: 19.7),
            start: cal.date(bySettingHour: 12, minute: 27, second: 0, of: cal.date(byAdding: .day, value: -7, to: .now)!)!,
            end: cal.date(bySettingHour: 12, minute: 27, second: 0, of: cal.date(byAdding: .day, value: -7, to: .now)!)!
        ))
    }
    
    private func addCustomSurveysHealthDashboardData() async throws {
        try await addCustomHealthSample(QuantitySample(
            id: UUID(),
            sampleType: .custom(.dietMEPAScore),
            unit: .count(),
            value: 10,
            date: cal.date(bySettingHour: 7, minute: 52, second: 0, of: .now)!
        ))
        try await addCustomHealthSample(QuantitySample(
            id: UUID(),
            sampleType: .custom(.nicotineExposure),
            unit: .count(),
            value: Double(NicotineExposureCategoryValues.quitWithin1To5Years.rawValue),
            date: cal.date(bySettingHour: 8, minute: 1, second: 0, of: .now)!
        ))
        try await addCustomHealthSample(QuantitySample(
            id: UUID(),
            sampleType: .custom(.mentalWellbeingScore),
            unit: .count(),
            value: 20,
            date: cal.date(bySettingHour: 8, minute: 7, second: 0, of: .now)!
        ))
    }
    
    private func removeAllDemoHealthKitData() async throws {
        func imp<Sample>(_ sampleType: some AnySampleType<Sample>) async throws {
            let sampleType = SampleType(sampleType)
            guard let samples = try? await healthKit.query(
                sampleType,
                timeRange: .ever,
                predicate: HKQuery.predicateForObjects(from: .default())
            ) else {
                return
            }
            if !samples.isEmpty {
                try await healthKit.healthStore.delete(samples)
            }
        }
        for sampleType in HKObjectType.allKnownObjectTypes.compactMap(\.sampleType) {
            try await imp(sampleType)
        }
    }
    
    private func addCustomHealthSample(_ sample: QuantitySample) async throws {
        try await standard.uploadHealthObservation(sample)
    }
    
    
    func addStepsData() async throws {
        struct SampleDescriptor {
            let start: Date
            let durationInMin: Int
            let numSteps: Int
            let distanceInMeters: Int
            let createWorkout: Bool
        }
        let descriptors = [
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -10, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 25198,
                distanceInMeters: 19800,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -9, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 15948,
                distanceInMeters: 10900,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -8, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 19056,
                distanceInMeters: 14200,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 12932,
                distanceInMeters: 9400,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 13972,
                distanceInMeters: 9300,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -5, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 15015,
                distanceInMeters: 10200,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -4, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 18102,
                distanceInMeters: 1400,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 3060,
                distanceInMeters: 3200,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 10730,
                distanceInMeters: 9100,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now))!,
                durationInMin: 60 * 12,
                numSteps: 4914,
                distanceInMeters: 3900,
                createWorkout: false
            ),
            SampleDescriptor(
                start: cal.startOfDay(for: .now),
                durationInMin: 12,
                numSteps: 1000,
                distanceInMeters: 100,
                createWorkout: true
            )
        ]
        
        for descriptor in descriptors {
            let endDate = cal.date(byAdding: .minute, value: descriptor.durationInMin, to: descriptor.start)!
            let stepsSample = HKQuantitySample(
                type: SampleType.stepCount.hkSampleType,
                quantity: HKQuantity(unit: .count(), doubleValue: Double(descriptor.numSteps)),
                start: descriptor.start,
                end: endDate
            )
            let distanceSample = HKQuantitySample(
                type: SampleType.distanceWalkingRunning.hkSampleType,
                quantity: HKQuantity(unit: .meter(), doubleValue: Double(descriptor.distanceInMeters)),
                start: descriptor.start,
                end: endDate
            )
            if descriptor.createWorkout {
                let workoutConfig = HKWorkoutConfiguration()
                workoutConfig.activityType = .running
                workoutConfig.locationType = .outdoor
                let workoutBuilder = HKWorkoutBuilder(healthStore: healthKit.healthStore, configuration: workoutConfig, device: .local())
                try await workoutBuilder.beginCollection(at: descriptor.start)
                try await workoutBuilder.addSamples([stepsSample, distanceSample])
                try await workoutBuilder.endCollection(at: endDate)
                try await workoutBuilder.finishWorkout()
            } else {
                try await healthKit.save([stepsSample, distanceSample])
            }
        }
    }
    
    // copied from the SpeziHealthKit UITests
    func addDemoSleepSamples() async throws {  // swiftlint:disable:this function_body_length
        struct SampleDescriptor {
            let phase: SleepSession.SleepPhase
            let duration: TimeInterval
        }
        let sampleDescriptors = [
            SampleDescriptor(phase: .asleepCore, duration: 750.0),
            SampleDescriptor(phase: .asleepDeep, duration: 300.0),
            SampleDescriptor(phase: .asleepCore, duration: 390.0),
            SampleDescriptor(phase: .asleepDeep, duration: 330.0),
            SampleDescriptor(phase: .asleepCore, duration: 30.0),
            SampleDescriptor(phase: .awake, duration: 30.0),
            SampleDescriptor(phase: .asleepCore, duration: 660.0),
            SampleDescriptor(phase: .asleepDeep, duration: 1350.0),
            SampleDescriptor(phase: .asleepCore, duration: 330.0),
            SampleDescriptor(phase: .asleepREM, duration: 630.0),
            SampleDescriptor(phase: .asleepCore, duration: 1140.0),
            SampleDescriptor(phase: .asleepDeep, duration: 1350.0),
            SampleDescriptor(phase: .asleepCore, duration: 930.0),
            SampleDescriptor(phase: .asleepDeep, duration: 390.0),
            SampleDescriptor(phase: .asleepCore, duration: 540.0),
            SampleDescriptor(phase: .asleepREM, duration: 870.0),
            SampleDescriptor(phase: .awake, duration: 60.0),
            SampleDescriptor(phase: .asleepCore, duration: 450.0),
            SampleDescriptor(phase: .asleepREM, duration: 90.0),
            SampleDescriptor(phase: .asleepCore, duration: 3180.0),
            SampleDescriptor(phase: .awake, duration: 90.0),
            SampleDescriptor(phase: .asleepCore, duration: 660.0),
            SampleDescriptor(phase: .asleepREM, duration: 2580.0),
            SampleDescriptor(phase: .asleepCore, duration: 3930.0),
            SampleDescriptor(phase: .awake, duration: 60.0),
            SampleDescriptor(phase: .asleepCore, duration: 180.0),
            SampleDescriptor(phase: .asleepREM, duration: 1350.0),
            SampleDescriptor(phase: .awake, duration: 60.0),
            SampleDescriptor(phase: .asleepCore, duration: 3690.0),
            SampleDescriptor(phase: .awake, duration: 840.0),
            SampleDescriptor(phase: .asleepCore, duration: 90.0)
        ]
        func makeSamples(from sampleDescriptors: [SampleDescriptor], startingAt startDate: Date) -> [HKCategorySample] {
            var samples: [HKCategorySample] = []
            for descriptor in sampleDescriptors {
                let start = samples.last?.endDate ?? startDate
                samples.append(HKCategorySample(
                    type: SampleType.sleepAnalysis.hkSampleType,
                    value: descriptor.phase.rawValue,
                    start: start,
                    end: start.addingTimeInterval(descriptor.duration)
                ))
            }
            return samples
        }
        let samples = makeSamples(
            from: sampleDescriptors,
            startingAt: cal.startOfPrevDay(for: .now)
        )
        logger.notice("[DBG] Adding \(samples.count) sleep samples to health")
        try await healthKit.save(samples)
    }
    
    
    private func addBloodPressureSamples() async throws {
        let date = cal.date(bySettingHour: 17, minute: 49, second: 0, of: cal.date(byAdding: .day, value: -1, to: .now)!)!
        let correlation = HKCorrelation(
            type: SampleType.bloodPressure.hkSampleType,
            start: date,
            end: date,
            objects: [
                HKQuantitySample(
                    type: SampleType.bloodPressureSystolic.hkSampleType,
                    quantity: HKQuantity(unit: SampleType.bloodPressureSystolic.displayUnit, doubleValue: 129),
                    start: date,
                    end: date
                ),
                HKQuantitySample(
                    type: SampleType.bloodPressureDiastolic.hkSampleType,
                    quantity: HKQuantity(unit: SampleType.bloodPressureSystolic.displayUnit, doubleValue: 90),
                    start: date,
                    end: date
                )
            ]
        )
        try await healthKit.save(correlation)
    }
}


extension NSError {
    enum MHCErrorCode: Int {
        case unspecified
    }
    
    convenience init(
        mhcErrorCode code: MHCErrorCode = .unspecified,
        localizedDescription: String
    ) {
        self.init(domain: "edu.stanford.MyHeartCounts", code: code.rawValue, userInfo: [
            NSLocalizedDescriptionKey: localizedDescription
        ])
    }
}


extension HealthKit.DataAccessRequirements {
    init(readAndWrite sampleTypes: some Sequence<any AnySampleType>) {
        self.init(readAndWrite: sampleTypes.map { $0.hkSampleType })
    }
}
