//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziSensorKit


extension SensorKit {
    static let mhcSensors: [any AnySensor] = [
        Sensor.onWrist,
        Sensor.ecg
    ]
    
    static let mhcSensorsExtended: [any AnySensor] = [
        Sensor.onWrist,
        Sensor.heartRate,
        Sensor.pedometer,
        Sensor.wristTemperature,
        Sensor.accelerometer,
        Sensor.ppg,
        Sensor.ecg,
        Sensor.ambientLight,
        Sensor.ambientPressure,
        Sensor.visits,
        Sensor.deviceUsage
    ]
    
    @SensorKitActor
    func exportNewSamples<Sample>(
        for sensor: Sensor<Sample>,
        standard: MyHeartCountsStandard
    ) async throws where Sample: HasCustomSamplesProcessor, Sample.Processor.Input == Sample, Sample.Processor.Output.Element: HealthObservation {
        try await exportNewSamples(for: sensor, standard: standard) {
            try await Sample.Processor.process($0)
        }
    }
    
    @SensorKitActor
    func exportNewSamples<Sample>(
        for sensor: Sensor<Sample>,
        standard: MyHeartCountsStandard,
        makeHealthObservations: @Sendable (
            SensorKit.FetchResultsIterator<Sample, [SensorKit.FetchResult<Sample>]>
        ) async throws -> some Collection<some HealthObservation> & Sendable
    ) async throws {
        for try await batch in try await fetchAnchored(sensor) {
            let healthObservations = try await makeHealthObservations(FetchResultsIterator(batch))
            try await standard.uploadHealthObservations(healthObservations)
        }
    }
}
