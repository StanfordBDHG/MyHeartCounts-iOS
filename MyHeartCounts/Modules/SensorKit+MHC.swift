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
    
    
    func exportNewSamples<Sample>(
        for sensor: Sensor<Sample>,
        standard: MyHeartCountsStandard
    ) async throws where Sample.SafeRepresentation: HealthObservation {
        for try await batch in try await fetchAnchored(sensor) {
            try await standard.uploadHealthObservations(batch)
        }
    }
}
