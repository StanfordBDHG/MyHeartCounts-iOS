//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziHealthKit


@Observable
final class HeartHealthManager: Module, EnvironmentAccessible {
    // swiftlint:disable attributes
    @ObservationIgnored @Dependency(HealthKit.self)
    private var healthKit
    // swiftlint:enable attributes
    
    @MainActor private(set) var layout: HealthDashboardLayout = []
    
    // TODO either fetch these from the study definition, or allow the user to configure them somewhere.
    // ALSO look into maybe reading the HealthKit ones?
    @MainActor let goals: [SampleType<HKQuantitySample>: HKQuantity] = [
        .activeEnergyBurned: HKQuantity(unit: .largeCalorie(), doubleValue: 500),
        .stepCount: HKQuantity(unit: .count(), doubleValue: 12500),
        .distanceWalkingRunning: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: 10)
    ]
    
    nonisolated init() {}
    
    func configure() {
        layout = [
            .largeChart(
                sectionTitle: nil,
                sampleType: .heartRate
            ),
            .grid(sectionTitle: "General", components: [
                .init(sampleType: SampleType.activeEnergyBurned),
                .init(sampleType: SampleType.stepCount),
                .init(sampleType: SampleType.distanceWalkingRunning),
                .init(sampleType: SampleType.heartRate)
            ]),
            .grid(sectionTitle: "Vitals", components: [
                .init(sampleType: SampleType.bodyTemperature),
                .init(sampleType: SampleType.heartRate),
                .init(sampleType: SampleType.respiratoryRate),
                .init(sampleType: SampleType.bloodPressure),
                .init(sampleType: SampleType.bloodOxygen)
            ]),
            .grid(sectionTitle: "Mobility", components: [
                .init(sampleType: SampleType.stepCount),
                .init(sampleType: SampleType.distanceWalkingRunning)
            ])
        ]
    }
}


extension HeartHealthManager {
}
