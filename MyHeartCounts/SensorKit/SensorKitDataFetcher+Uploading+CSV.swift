//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import CryptoKit
import Foundation
import ModelsR4
import OSLog
import SpeziFoundation
import SpeziSensorKit


protocol CSVAppendableSensorSample: SensorKitSampleSafeRepresentation {
    static var csvColumns: [String] { get }
    
    var csvFieldValues: [any CSVWriter.FieldValue] { get }
}


/// An upload strategy that encodes a batch of samples into a CSV files, uploads that, and creates a corresponding FHIR observation.
struct UploadStrategyCSVFile<Sample: SensorKitSampleProtocol>: MHCSensorSampleUploadStrategy
where Sample.SafeRepresentation: CSVAppendableSensorSample {
    func upload(
        _ samples: some Collection<Sample.SafeRepresentation> & Sendable,
        batchInfo: SensorKit.BatchInfo,
        for sensor: Sensor<Sample>,
        to standard: MyHeartCountsStandard
    ) async throws {
        SensorKitDataFetcher.logger.notice(
            "Uploading \(samples.count) \(sensor.displayName) samples as CSV-encoded compressed files. (\(batchInfo.timeRange))"
        )
        guard !samples.isEmpty else {
            return
        }
        let writer = try CSVWriter(columns: Sample.SafeRepresentation.csvColumns + ["device"])
        SensorKitDataFetcher.logger.notice("[\(sensor.displayName)] Writing samples to CSV")
        try measure("[sk] csv") {
            let deviceInfoCol = CollectionOfOne<any CSVWriter.FieldValue>(batchInfo.device.description)
            for sample in samples {
                try writer.appendRow(fields: chain(sample.csvFieldValues, deviceInfoCol))
            }
        }
        let data = try writer.data().compressed(using: Zlib.self)
        let sha1 = Insecure.SHA1.hash(data: data)
        let size = data.count
        let url = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("csv.zlib")
        try (consume data).write(to: url)
        SensorKitDataFetcher.logger.notice("[\(sensor.displayName)] Submitting compressed CSV for upload")
        await standard.uploadSensorKitCSV(at: url, for: sensor)
        let attachment = Attachment(
            contentType: "application/zlib",
            creation: try FHIRPrimitive(DateTime(date: .now)),
            hash: FHIRPrimitive(Base64Binary(Data(sha1).base64EncodedString())),
            // for some reason, R4 uses a "32-bit unsigned integer"
            // (which is what they say when they actually mean a 31-bit unsigned integer; don't ask why)
            // to store the size of the attachment.
            // this means, in effect, that we can provide size info for files up to 2GB.
            // for anything above that, we set the size to nil.
            size: Int32(exactly: size).map { FHIRPrimitive(FHIRUnsignedInteger($0)) },
            // NOTE: we use a path relative to this user's storage directory here!
            url: ManagedFileUpload.Category(sensor).firebasePath.asFHIRURIPrimitive()! // swiftlint:disable:this force_unwrapping
        )
        let docRef = DocumentReference(
            content: [.init(attachment: attachment)],
            status: FHIRPrimitive(.current)
        )
        let observation = Observation(
            code: CodeableConcept(), // TODO coding!!!!
            status: FHIRPrimitive(.final)
        )
//        observation.derivedFrom = [Reference(display: <#T##FHIRPrimitive<FHIRString>?#>, extension: <#T##[Extension]?#>, id: <#T##FHIRPrimitive<FHIRString>?#>, identifier: <#T##Identifier?#>, reference: <#T##FHIRPrimitive<FHIRString>?#>, type: <#T##FHIRPrimitive<FHIRURI>?#>)]
    }
}
