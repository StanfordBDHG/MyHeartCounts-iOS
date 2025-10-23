//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import OSLog
import Spezi
import SpeziFoundation
import SpeziSensorKit


protocol MHCSensorSampleUploadStrategy<Sample>: Sendable {
    associatedtype Sample: SensorKitSampleProtocol
    
    func upload(
        _ samples: some Collection<Sample.SafeRepresentation> & Sendable,
        from device: SensorKit.DeviceInfo,
        for sensor: Sensor<Sample>,
        to standard: MyHeartCountsStandard
    ) async throws
}


struct UploadStrategyFHIRObservations<Sample: SensorKitSampleProtocol>: MHCSensorSampleUploadStrategy
where Sample.SafeRepresentation: HealthObservation {
    func upload(
        _ samples: some Collection<Sample.SafeRepresentation> & Sendable,
        from device: SensorKit.DeviceInfo,
        for sensor: Sensor<Sample>,
        to standard: MyHeartCountsStandard
    ) async throws {
        SensorKitDataFetcher.logger.notice("Uploading \(samples.count) \(sensor.displayName) samples as FHIR observations")
        try await standard.uploadHealthObservations(samples)
    }
}


protocol CSVAppendableSensorSample: SensorKitSampleSafeRepresentation {
    static var csvColumns: [String] { get }
    
    var csvFieldValues: [any CSVFieldValue] { get }
}


struct UploadStrategyCSVFile<Sample: SensorKitSampleProtocol>: MHCSensorSampleUploadStrategy
where Sample.SafeRepresentation: CSVAppendableSensorSample {
    func upload(
        _ samples: some Collection<Sample.SafeRepresentation> & Sendable,
        from device: SensorKit.DeviceInfo,
        for sensor: Sensor<Sample>,
        to standard: MyHeartCountsStandard
    ) async throws {
        SensorKitDataFetcher.logger.notice("Uploading \(samples.count) \(sensor.displayName) samples as CSV-encoded compressed files")
        guard !samples.isEmpty else {
            return
        }
        let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, conformingTo: .commaSeparatedText)
        let writer = try CSVWriter(url: url, columns: Sample.SafeRepresentation.csvColumns + ["device"])
        for sample in samples {
            let columns: [any CSVFieldValue] = sample.csvFieldValues + [device.description]
            try writer.appendRow(fields: columns)
        }
        _ = consume writer
        let data = try Data(contentsOf: url)
        let compressed = try data.compressed(using: Zlib.self)
        let compressedUrl = url.appendingPathExtension("zlib")
        try compressed.write(to: compressedUrl)
        try? FileManager.default.removeItem(at: url)
        await standard.uploadSensorKitCSV(at: compressedUrl, for: sensor)
    }
}


protocol MHCUploadableSensor<Sample>: AnySensor {
    associatedtype UploadStrategy: MHCSensorSampleUploadStrategy
}


protocol AnyMHCSensorUploadDefinition<Sample, UploadStrategy>: Sendable {
    associatedtype Sample: SensorKitSampleProtocol
    associatedtype UploadStrategy: MHCSensorSampleUploadStrategy where UploadStrategy.Sample == Sample
    
    var sensor: Sensor<Sample> { get }
    var strategy: UploadStrategy { get }
}

extension AnyMHCSensorUploadDefinition {
    var typeErasedSensor: any AnySensor {
        sensor
    }
}


struct MHCSensorUploadDefinition<
    Sample: SensorKitSampleProtocol,
    UploadStrategy: MHCSensorSampleUploadStrategy<Sample>
>: AnyMHCSensorUploadDefinition {
    typealias Sample = Sample
    typealias UploadStrategy = UploadStrategy
    
    let sensor: Sensor<Sample>
    let strategy: UploadStrategy
    
    init(sensor: Sensor<Sample>, strategy: UploadStrategy) {
        self.sensor = sensor
        self.strategy = strategy
    }
    
    init(_ typeErased: any AnyMHCSensorUploadDefinition<Sample, UploadStrategy>) {
        // SAFETY: `MHCSensorDefinition` is the only type allowed to conform to `AnyMHCSensorDefinition`.
        self = typeErased as! Self // swiftlint:disable:this force_cast
    }
}
