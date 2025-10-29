//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable legacy_objc_type all

import Foundation
import HealthKitOnFHIR
import ModelsR4
import SensorKit
import SpeziFoundation
import SpeziSensorKit


extension SRPhotoplethysmogramSample {
    struct UploadStrategy: MHCSensorSampleUploadStrategy {
        typealias Sample = SRPhotoplethysmogramSample
        
        func upload(
            _ samples: some Collection<Sample.SafeRepresentation> & Sendable,
            batchInfo: SensorKit.BatchInfo,
            for sensor: Sensor<SRPhotoplethysmogramSample>,
            to standard: MyHeartCountsStandard,
            activity: SensorKitDataFetcher.InProgressActivity
        ) async throws {
            for sample in samples {
                let jsonData = try Self.toJSON(sample.sample)
                try await self.upload(
                    data: jsonData,
                    fileExtension: "json",
                    for: sensor,
                    deviceInfo: batchInfo.device,
                    to: standard,
                    observationDocName: sample.id.uuidString,
                    activity: activity
                ) { observation in
                    let (minDate, maxDate) = {
                        var maxDate = sample.startDate
                        for sample in sample.opticalSamples {
                            maxDate = max(maxDate, maxDate.addingNanoseconds(sample.nanosecondsSinceStart))
                        }
                        return (sample.startDate, maxDate)
                    }()
                    observation.effective = try .period(Period(
                        end: FHIRPrimitive(DateTime(date: maxDate)),
                        start: FHIRPrimitive(DateTime(date: minDate))
                    ))
                }
            }
        }
    }
}

extension SRPhotoplethysmogramSample.UploadStrategy {
    private static func toJSON(_ sample: SRPhotoplethysmogramSample) throws -> Data {
        let dict = NSMutableDictionary()
        dict["startDate"] = sample.startDate.timeIntervalSince1970
        dict["nanosecondsSinceStart"] = sample.nanosecondsSinceStart
        dict["usage"] = sample.usage.map(\.rawValue)
        dict["opticalSamples"] = sample.opticalSamples.map { (sample: SRPhotoplethysmogramOpticalSample) in
            NSDictionary(dictionary: [
                "emitter": sample.emitter,
                "activePhotodiodeIndexes": Array(sample.activePhotodiodeIndexes),
                "signalIdentifier": sample.signalIdentifier,
                "nominalWavelength": sample.nominalWavelength.converted(to: .nanometers).value,
                "effectiveWavelength": sample.effectiveWavelength.converted(to: .nanometers).value,
                "samplingFrequency": sample.samplingFrequency.converted(to: .hertz).value,
                "nanosecondsSinceStart": sample.nanosecondsSinceStart,
                "conditions": sample.conditions.map(\.rawValue),
                "noiseTerms": sample.noiseTerms.flatMap { noiseTerms in
                    NSDictionary(dictionary: [
                        "whiteNoise": noiseTerms.whiteNoise,
                        "pinkNoise": noiseTerms.pinkNoise,
                        "backgroundNoise": noiseTerms.backgroundNoise,
                        "backgroundNoiseOffset": noiseTerms.backgroundNoiseOffset
                    ])
                } as Any,
                "normalizedReflectance": sample.normalizedReflectance as Any
            ])
        }
        dict["accelerometerSamples"] = sample.accelerometerSamples.map { (sample: SRPhotoplethysmogramAccelerometerSample) in
            NSDictionary(dictionary: [
                "nanosecondsSinceStart": sample.nanosecondsSinceStart,
                "samplingFrequency": sample.samplingFrequency.converted(to: .hertz).value,
                "x": sample.x.converted(to: .gravity).value,
                "y": sample.y.converted(to: .gravity).value,
                "z": sample.z.converted(to: .gravity).value
            ])
        }
        dict["temperature"] = sample.temperature?.converted(to: .celsius).value
        return try JSONSerialization.data(withJSONObject: dict)
    }
}


extension SRPhotoplethysmogramSample: FileProcessableSensorSampleProtocol {
    static var fileExtension: String { "json" } // likely not a good idea!
}


extension SRPhotoplethysmogramSample: Identifiable {
    public var id: UUID {
        var hasher = SensorKitSampleIDHasher()
        hasher.combine(startDate)
        hasher.combine(nanosecondsSinceStart)
        hasher.combine(usage.count)
        hasher.combine(opticalSamples.count)
        hasher.combine(accelerometerSamples.count)
        hasher.combine(temperature?.value)
        return hasher.finalize()
    }
}


extension Date {
    func addingNanoseconds(_ nanoseconds: Int64) -> Date {
        addingTimeInterval(TimeInterval(nanoseconds) / 1_000_000_000)
    }
}
