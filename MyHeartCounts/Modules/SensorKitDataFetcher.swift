//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import Spezi
import SpeziSensorKit


final class SensorKitDataFetcher: Module {
    // swiftlint:disable attributes
    @StandardActor private var standard: MyHeartCountsStandard
    @Dependency(SensorKit.self) private var sensorKit
    @Application(\.logger) private var logger
    // swiftlint:enable attributes
    
    func configure() {
        Task(priority: .background) {
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
                try await sensorKit.exportNewSamples(for: sensor, standard: standard)
            } catch {
                logger.error("Failed to fetch & upload data for Sensor '\(sensor.displayName)': \(error)")
            }
        }
        await imp(.onWrist)
        await imp(.ecg)
    }
}
