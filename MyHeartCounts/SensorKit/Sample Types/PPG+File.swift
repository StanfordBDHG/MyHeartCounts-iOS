//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKitOnFHIR
import ModelsR4
import NIOCore
import NIOFoundationCompat
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
            guard !samples.isEmpty else {
                return
            }
            print("will encode \(samples.count) into a binary format")
            let buffer = try BinaryEncoder.encode(samples.lazy.map(\.sample))
            guard let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes, byteTransferStrategy: .noCopy) else {
                fatalError() // TODO be more graceful here!
                return
            }
            try await self.upload(
                data: data,
                fileExtension: "mhcPPG",
                for: sensor,
                deviceInfo: batchInfo.device,
                to: standard,
                observationDocName: "\(batchInfo.timeRange.lowerBound.ISO8601Format())_\(batchInfo.timeRange.upperBound.ISO8601Format())",
                activity: activity
            ) { observation in
                // TODO
//                let (minDate, maxDate) = {
//                    var maxDate = sample.startDate
//                    for sample in sample.opticalSamples {
//                        maxDate = max(maxDate, maxDate.addingNanoseconds(sample.nanosecondsSinceStart))
//                    }
//                    return (sample.startDate, maxDate)
//                }()
//                observation.effective = try .period(Period(
//                    end: FHIRPrimitive(DateTime(date: maxDate)),
//                    start: FHIRPrimitive(DateTime(date: minDate))
//                ))
            }
        }
    }
}


extension SRPhotoplethysmogramSample: @retroactive Identifiable {
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
