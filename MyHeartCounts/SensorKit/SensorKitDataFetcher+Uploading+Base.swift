//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CryptoKit
import FHIRModelsExtensions
@preconcurrency import FirebaseFirestore
import Foundation
import ModelsR4
import SpeziFHIR
import SpeziFirestore
import SpeziFoundation
import SpeziHealthKitFHIR
import SpeziSensorKit


extension MHCSensorSampleUploadStrategy {
    func upload( // swiftlint:disable:this function_parameter_count function_body_length
        data: consuming Data,
        for sensor: Sensor<Sample>,
        batchInfo: SensorKit.BatchInfo,
        effectiveTimeRange: Swift.Range<Date>,
        recordID: UUID? = nil,
        shouldCompress: Bool = true,
        to standard: MyHeartCountsStandard,
        documentName: String,
        activity: SensorKitDataFetcher.InProgressActivity,
        postprocess: (inout SensorKitRecordingResource) throws -> Void = { _ in }
    ) async throws {
        #if canImport(GroveSensorKitFHIR)
        let stream = try SensorKitGroveStream(sensor)
        let recordID = recordID ?? stream.recordID(for: data, from: batchInfo.device)
        let filename = "\(recordID.uuidString).\(stream.format.fileExtension)"
        // The registry format describes the exact payload bytes; the sidecar file therefore stays uncompressed.
        let url = URL.temporaryDirectory.appending(component: filename)
        try data.write(to: url)
        
        activity.updateMessage("Submitting for upload")
        // Note: this call does not wait for the upload to get completed;
        // it just looks like it bc the standard is an actor...
        await standard.uploadSensorKitFile(at: url, for: sensor)
        
        activity.updateMessage("Creating Recording Document")
        let title = "\(sensor.displayName) \(effectiveTimeRange.lowerBound.ISO8601Format())_\(effectiveTimeRange.upperBound.ISO8601Format())"
        let accountId = try await standard.firebaseConfiguration.accountId
        var document = try SensorKitGroveRecording.document(
            payload: data,
            recordID: recordID,
            stream: stream,
            // NOTE: the path is relative to this user's storage directory, and has to match the location the file upload above ends up at!
            sidecarPath: "\(ManagedFileUpload.Category(sensor).firebasePath)/\(filename)",
            title: title,
            device: batchInfo.device,
            effectiveTimeRange: effectiveTimeRange,
            accountId: accountId
        )
        document.addMHCAppAsSource()
        try document.apply(.sensorKitSourceDevice, input: batchInfo.device)
        for builder in MyHeartCountsStandard.defaultHealthObservationFHIRExtensions {
            try builder.apply(typeErasedInput: self, to: &document)
        }
        try postprocess(&document)
        
        let sensorCollection = try await standard.firebaseConfiguration.userDocumentReference
            .collection("HealthObservations_\(sensor.id)")
        try await sensorCollection.document(documentName).setData(from: document)
        #else
        activity.updateMessage("Compressing Data")
        let data = shouldCompress ? try (consume data).compressed(using: Zstd.self) : consume data
        let sha1 = Insecure.SHA1.hash(data: data)
        let size = data.count
        let fileExtension = try SensorKitGroveStream(sensor).format.fileExtension
        let url = URL.temporaryDirectory
            .appending(component: UUID().uuidString)
            .appendingPathExtension("\(fileExtension)\(shouldCompress ? ".zstd" : "")")
        try (consume data).write(to: url)
        
        activity.updateMessage("Submitting for upload")
        // Note: this call does not wait for the upload to get completed;
        // it just looks like it bc the standard is an actor...
        await standard.uploadSensorKitFile(at: url, for: sensor)
        
        let referenceDocName = documentName + "_Ref"
        
        let attachment = Attachment(
            contentType: "application/zstd",
            creation: try FHIRPrimitive(DateTime(date: .now)),
            hash: FHIRPrimitive(Base64Binary(Data(sha1).base64EncodedString())),
            // for some reason, R4 uses a "32-bit unsigned integer"
            // (which is what they say when they actually mean a 31-bit unsigned integer; don't ask why)
            // to store the size of the attachment.
            // this means, in effect, that we can provide size info for files up to 2GB.
            // for anything above that, we set the size to nil.
            size: Int32(exactly: size).map { FHIRPrimitive(FHIRUnsignedInteger($0)) },
            // NOTE: we use a path relative to this user's storage directory here!
            url: ManagedFileUpload.Category(sensor).firebasePath.appending("/\(url.lastPathComponent)").asFHIRURIPrimitive()
        )
        let reference = DocumentReference(
            content: [.init(attachment: attachment)],
            status: FHIRPrimitive(.current)
        )
        var observation = Observation(
            code: CodeableConcept(),
            status: FHIRPrimitive(.final)
        )
        observation.id = documentName.asFHIRStringPrimitive()
        observation.append(coding: Coding(code: SensorKitCodingSystem(sensor)))
        try observation.setIssued(on: .now)
        observation.append(
            // Note: the value here has to match the firestore document used to upload the reference!
            Reference(reference: "HealthObservations_\(sensor.id)/\(referenceDocName)".asFHIRStringPrimitive()),
            to: \.derivedFrom
        )
        
        observation.addMHCAppAsSource()
        try observation.apply(.sensorKitSourceDevice, input: batchInfo.device)
        for builder in MyHeartCountsStandard.defaultHealthObservationFHIRExtensions {
            try builder.apply(typeErasedInput: self, to: &observation)
        }
        observation.effective = try .period(Period(
            end: FHIRPrimitive(DateTime(date: effectiveTimeRange.upperBound)),
            start: FHIRPrimitive(DateTime(date: effectiveTimeRange.lowerBound))
        ))
        try postprocess(&observation)
        
        let sensorCollection = try await standard.firebaseConfiguration.userDocumentReference
            .collection("HealthObservations_\(sensor.id)")
        try await sensorCollection.document(referenceDocName).setData(from: reference)
        try await sensorCollection.document(documentName).setData(from: observation)
        #endif
    }
}
