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
//            .largeChart(
//                sectionTitle: nil,
//                component: .init(sampleType: .heartRate, timeRange: <#T##HealthKitQueryTimeRange#>, chartConfig: <#T##HealthDashboardLayout.ChartConfig#>)
//                sampleType: .heartRate,
//                chartConfig: .automatic
//            ),
            .grid(sectionTitle: "General", components: [
                .init(SampleType.activeEnergyBurned, chartConfig: .automatic),
                .init(SampleType.stepCount, chartConfig: .automatic),
                .init(SampleType.distanceWalkingRunning, chartConfig: .automatic),
                .init(SampleType.heartRate, chartConfig: .automatic)
            ]),
            .grid(sectionTitle: "Additional", components: [
                .sleepAnalysis(),
                .init(SampleType.respiratoryRate, chartConfig: .automatic),
                .init(SampleType.bodyTemperature, chartConfig: .automatic),
                .init(SampleType.bloodOxygen, chartConfig: .automatic),
                .bloodPressure()
            ]),
            .grid(sectionTitle: "Mobility", components: [
                .init(SampleType.stepCount, chartConfig: .automatic),
                .init(SampleType.distanceWalkingRunning, chartConfig: .automatic),
                .init(SampleType.walkingDoubleSupportPercentage, chartConfig: .none)
            ])
        ]
    }
    
    
    @MainActor
    func tmpAddSection() {
        layout.blocks.append(.grid(sectionTitle: "Tmp Section", components: [
            .init(.stepCount, chartConfig: .automatic)
        ]))
    }
    
    @MainActor
    func tmpRemoveSection() {
        if !layout.blocks.isEmpty {
            layout.blocks.removeLast()
        }
    }
}


extension HeartHealthManager {
}
