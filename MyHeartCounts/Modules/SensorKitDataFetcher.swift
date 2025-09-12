//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import Spezi
import SpeziFoundation
import SpeziSensorKit


final class SensorKitDataFetcher: Module {
    // swiftlint:disable attributes
    @StandardActor private var standard: MyHeartCountsStandard
    @Dependency(SensorKit.self) private var sensorKit
    @Application(\.logger) private var logger
    // swiftlint:enable attributes
    
    func configure() {
        _Concurrency.Task(priority: .background) {
            await doFetch()
        }
    }
    
    
    @concurrent
    private func doFetch() async {
        func imp<Sample>(_ sensor: Sensor<Sample>) async where Sample.SafeRepresentation: HealthObservation {
            guard sensorKit.authorizationStatus(for: sensor) == .authorized else {
                logger.notice("Skipping Sensor '\(sensor.displayName)' bc it's not authorized.")
                return
            }
            do {
                logger.notice("will fetch new samples for Sensor '\(sensor.displayName)'")
                for try await batch in try await sensorKit.fetchAnchored(sensor) {
                    try await standard.uploadHealthObservations(batch)
                }
            } catch {
                logger.error("Failed to fetch & upload data for Sensor '\(sensor.displayName)': \(error)")
            }
        }
        await imp(.onWrist)
        await imp(.ecg)
    }
    
    
    /// Fetches all SensorKit samples for the specified sensor, and uploads them all into the Firestore.
    ///
    /// Primarily intended for testing purposes.
    @concurrent
    private func fetchAndUploadAll<Sample>(for sensor: Sensor<Sample>) async throws where Sample.SafeRepresentation: HealthObservation {
        let reader = SensorReader(sensor)
        let devices = try await reader.fetchDevices()
        for device in devices {
            let newestSampleDate = Date.now.addingTimeInterval(-sensor.dataQuarantineDuration.timeInterval)
            let oldestSampleDate = newestSampleDate.addingTimeInterval(-TimeConstants.day * 5.5)
            for startDate in stride(from: oldestSampleDate, through: newestSampleDate, by: sensor.suggestedBatchSize.timeInterval) {
                let timeRange = startDate..<min(startDate.addingTimeInterval(sensor.suggestedBatchSize.timeInterval), newestSampleDate)
                let samples = (try? await reader.fetch(from: device, timeRange: timeRange)) ?? []
                try await standard.uploadHealthObservations(samples)
            }
        }
    }
}


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
}
