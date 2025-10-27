//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import SpeziSensorKit


/// An upload strategy that uploads each sample as a FHIR observation.
struct UploadStrategyFHIRObservations<Sample: SensorKitSampleProtocol>: MHCSensorSampleUploadStrategy
where Sample.SafeRepresentation: HealthObservation {
    func upload(
        _ samples: some Collection<Sample.SafeRepresentation> & Sendable,
        batchInfo: SensorKit.BatchInfo,
        for sensor: Sensor<Sample>,
        to standard: MyHeartCountsStandard
    ) async throws {
        SensorKitDataFetcher.logger.notice("Uploading \(samples.count) \(sensor.displayName) samples as FHIR observations")
        try await standard.uploadHealthObservations(samples)
    }
}
