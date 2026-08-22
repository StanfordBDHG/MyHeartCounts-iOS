//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CryptoKit
import Foundation
import ModelsR4
import SensorKit
import SpeziSensorKit
#if canImport(GroveSensorKitFHIR)
import GroveFHIRContract
import GroveSensorKitFHIR
#endif


// The Grove recording document replaces the bespoke Observation wrapper once the GroveSensorKitFHIR package is part of the build;
// until then the bespoke wrapper remains in place as the fallback.
#if canImport(GroveSensorKitFHIR)
/// The FHIR resource each SensorKit batch upload gets wrapped in.
typealias SensorKitRecordingResource = DocumentReference
#else
/// The FHIR resource each SensorKit batch upload gets wrapped in.
typealias SensorKitRecordingResource = Observation
#endif


/// The Grove recording-format registry entry backing a SensorKit stream's raw payload.
struct SensorKitGroveStream {
    /// A payload format admitted by the Grove recording format registry.
    enum Format {
        case groveCSV1
        case fhirJSON1
        case grovePPG1
        
        /// The format's code in the registry's code system.
        var code: String {
            switch self {
            case .groveCSV1: "grove-csv-1"
            case .fhirJSON1: "fhir-json-1"
            case .grovePPG1: "grove-ppg-1"
            }
        }
        
        /// The format's display name in the registry.
        var display: String {
            switch self {
            case .groveCSV1: "Grove CSV 1"
            case .fhirJSON1: "FHIR JSON Array 1"
            case .grovePPG1: "Grove PPG Binary 1"
            }
        }
        
        /// The content type the registry declares for the format.
        var contentType: String {
            switch self {
            case .groveCSV1: "text/csv"
            case .fhirJSON1: "application/json"
            case .grovePPG1: "application/octet-stream"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .groveCSV1: "csv"
            case .fhirJSON1: "json"
            case .grovePPG1: "mhcPPG"
            }
        }
    }
    
    private static let streams: [SRSensor: SensorKitGroveStream] = [
        .heartRate: SensorKitGroveStream(sourceToken: "SRSensor.heartRate", format: .groveCSV1),
        .accelerometer: SensorKitGroveStream(sourceToken: "SRSensor.accelerometer", format: .groveCSV1),
        .ambientLightSensor: SensorKitGroveStream(sourceToken: "SRSensor.ambientLightSensor", format: .groveCSV1),
        .ambientPressure: SensorKitGroveStream(sourceToken: "SRSensor.ambientPressure", format: .groveCSV1),
        .pedometerData: SensorKitGroveStream(sourceToken: "SRSensor.pedometerData", format: .groveCSV1),
        .wristTemperature: SensorKitGroveStream(sourceToken: "SRSensor.wristTemperature", format: .groveCSV1),
        .visits: SensorKitGroveStream(sourceToken: "SRSensor.visits", format: .fhirJSON1),
        .onWristState: SensorKitGroveStream(sourceToken: "SRSensor.onWristState", format: .fhirJSON1),
        .deviceUsageReport: SensorKitGroveStream(sourceToken: "SRSensor.deviceUsageReport", format: .fhirJSON1),
        .electrocardiogram: SensorKitGroveStream(sourceToken: "SRSensor.electrocardiogram", format: .fhirJSON1),
        .photoplethysmogram: SensorKitGroveStream(sourceToken: "SRSensor.photoplethysmogram", format: .grovePPG1)
    ]
    
    /// The stream's source token in the Grove SensorKit catalog.
    let sourceToken: String
    /// The registry format of the payload the stream's upload strategy produces.
    let format: Format
    
    init(_ sensor: some AnySensor) throws {
        guard let stream = Self.streams[sensor.srSensor] else {
            throw SensorKitGroveRecordingError.unsupportedSensor(sensor.id)
        }
        self = stream
    }
    
    private init(sourceToken: String, format: Format) {
        self.sourceToken = sourceToken
        self.format = format
    }
    
    /// Derives the producer-assigned record UUID from the exact payload bytes.
    ///
    /// Identical bytes from the same stream and device yield the same identity across retries;
    /// any change produces a fresh UUID, matching the Grove contract's reuse rule for source record identifiers.
    func recordID(for payload: Data, from device: SensorKit.DeviceInfo) -> UUID {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("\(sourceToken)|\(device.description)|".utf8))
        hasher.update(data: payload)
        return Data(hasher.finalize().prefix(16))
            .withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
            .makeValidV4()
    }
}


enum SensorKitGroveRecordingError: Error {
    case unsupportedSensor(String)
    case missingRecordingDocument
}


#if canImport(GroveSensorKitFHIR)
/// Wraps a SensorKit batch payload into a Grove SensorKit recording document.
enum SensorKitGroveRecording {
    private static let applicationIdentifierSystem = "https://bdh.stanford.edu/fhir/defs/SensorKit/application"
    private static let deviceIdentifierSystem = "https://bdh.stanford.edu/fhir/defs/SensorKit/sourceDevice"
    private static let graphIdentifierSystem = "https://bdh.stanford.edu/fhir/defs/SensorKit/graph"
    private static let recordingFormatSystem: FHIRPrimitive<FHIRURI> = "https://grovealliance.org/fhir/sensor/CodeSystem/grove-recording-format"
    
    static func document( // swiftlint:disable:this function_parameter_count
        payload: Data,
        recordID: UUID,
        stream: SensorKitGroveStream,
        sidecarPath: String,
        title: String,
        device: SensorKit.DeviceInfo,
        effectiveTimeRange: Swift.Range<Date>,
        accountId: String
    ) throws -> DocumentReference {
        let recording = try GroveSensorKitNativeRecording(
            title: title,
            contentType: stream.format.contentType,
            payload: .sidecar(path: sidecarPath, bytes: payload),
            // the payloads are the app's own encodings of the exact SensorKit records; they carry no data beyond the source samples.
            admission: .callerAuthorizedOpaquePayload,
            format: Coding(
                code: stream.format.code.asFHIRStringPrimitive(),
                display: stream.format.display.asFHIRStringPrimitive(),
                system: recordingFormatSystem
            )
        )
        let record = GroveSensorKitRawRecord(
            sourceRecordID: GroveSensorKitSourceRecordID(recordID),
            sourceToken: stream.sourceToken,
            nativeRecording: recording
        )
        let conversion = try GroveSensorKitFHIRConverter().convert(.raw(record), context: context(for: device, accountId: accountId))
        guard var document = conversion.recordingDocument else {
            throw SensorKitGroveRecordingError.missingRecordingDocument
        }
        var documentContext = document.context ?? DocumentReferenceContext()
        documentContext.period = Period(
            end: FHIRPrimitive(try DateTime(date: effectiveTimeRange.upperBound)),
            start: FHIRPrimitive(try DateTime(date: effectiveTimeRange.lowerBound))
        )
        document.context = documentContext
        return document
    }
    
    private static func context(for device: SensorKit.DeviceInfo, accountId: String) throws -> GroveSensorKitFHIRConversionContext {
        GroveSensorKitFHIRConversionContext(
            subject: Reference(reference: "Patient/\(accountId)".asFHIRStringPrimitive()),
            converter: GroveSensorFHIRApplication(
                identifier: try GroveFHIRBusinessIdentifier(
                    system: applicationIdentifierSystem,
                    value: "edu.stanford.MyHeartCounts"
                ),
                name: "My Heart Counts",
                version: Bundle.main.appVersion
            ),
            graphIdentifierSystem: graphIdentifierSystem,
            recordingDevice: GroveSensorFHIRRecordingDevice(
                identifier: try GroveFHIRBusinessIdentifier(
                    system: deviceIdentifierSystem,
                    value: "\(device.productType)|\(device.name)"
                ),
                name: device.name,
                manufacturer: "Apple",
                modelNumber: device.productType
            ),
            sourceTimeZone: .current,
            issuedAt: .now,
            recordedAt: .now
        )
    }
}
#endif
