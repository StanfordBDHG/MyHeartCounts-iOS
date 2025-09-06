//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import HealthKitOnFHIR
import ModelsR4
import SensorKit
import SpeziSensorKit


// MARK: On-Wrist Detection

extension SRWristDetection: HasCustomSamplesProcessor {
    struct Processor: SensorKitSamplesProcessor {
        typealias Input = SRWristDetection
        typealias Output = [SensorKitOnWristEventSample]
        
        static func process(_ samples: some Sequence<(timestamp: Date, sample: SRWristDetection)>) -> [SensorKitOnWristEventSample] {
            samples.map { .init(timestamp: $0, sample: $1) }
        }
    }
}


struct SensorKitOnWristEventSample: Hashable, Sendable {
    static var sensor: Sensor<SRWristDetection> {
        .onWrist
    }
    
    let id: UUID
    
    /// The date when this sample was collected
    let timestamp: Date
    
    /// Whether the watch was on the user's wrist.
    let onWrist: Bool
    let wristLocation: SRWristDetection.WristLocation
    let crownOrientation: SRWristDetection.CrownOrientation
    
    /// Start date of the recent on-wrist state.
    ///
    /// When the state changes from off-wrist to on-wrist, ``onWristDate`` would be updated to the current date, and ``offWristDate`` would remain the same.
    /// When the state changes from on-wrist to off-wrist, ``offWristDate`` would be updated to the current date, and ``onWristDate`` would remain the same.
    let onWristDate: Date?
    
    /// Start date of the recent off-wrist state.
    ///
    /// When the state changes from off-wrist to on-wrist, ``onWristDate`` would be updated to the current date, and ``offWristDate`` would remain the same.
    /// When the state changes from on-wrist to off-wrist, ``offWristDate`` would be updated to the current date, and ``onWristDate`` would remain the same.
    let offWristDate: Date?
    
    init(timestamp: Date, sample: SRWristDetection) {
        self.id = UUID() // ewwww
        self.timestamp = timestamp
        self.onWrist = sample.onWrist
        self.wristLocation = sample.wristLocation
        self.crownOrientation = sample.crownOrientation
        self.onWristDate = sample.onWristDate
        self.offWristDate = sample.offWristDate
    }
}


// MARK: FHIR

extension SensorKitOnWristEventSample: HealthObservation {
    var sampleTypeIdentifier: String {
        Sensor.onWrist.id
    }
    
    func resource(
        withMapping mapping: HKSampleMapping,
        issuedDate _: FHIRPrimitive<Instant>?,
        extensions: [any FHIRExtensionBuilderProtocol]
    ) throws -> ResourceProxy {
        let observation = Observation(
            code: CodeableConcept(),
            status: FHIRPrimitive(.final)
        )
        observation.id = self.id.uuidString.asFHIRStringPrimitive()
        observation.appendIdentifier(Identifier(id: observation.id))
        switch (onWristDate, offWristDate) {
        case (.none, .none):
            break
        case (.some(let date), .none), (.none, .some(let date)):
            observation.effective = try .instant(.init(Instant(date: date)))
        case let (.some(onWristDate), .some(offWristDate)):
            observation.effective = try .period(Period(
                end: .init(DateTime(date: max(onWristDate, offWristDate))),
                start: .init(DateTime(date: min(onWristDate, offWristDate)))
            ))
        }
        try observation.setIssued(on: self.timestamp)
        observation.value = .boolean(.init(.init(onWrist)))
        observation.appendComponent(ObservationComponent(
            code: SpeziCodingSystem.watchWristLocation,
            value: wristLocation.observationValue
        ))
        observation.appendComponent(ObservationComponent(
            code: SpeziCodingSystem.watchCrownOrientation,
            value: crownOrientation.observationValue
        ))
        for builder in extensions {
            try builder.apply(typeErasedInput: self, to: observation)
        }
        try observation.addMHCAppAsSource()
        return .observation(observation)
    }
}


extension SRWristDetection.WristLocation {
    fileprivate var observationValue: ObservationComponent.ValueX? {
        switch self {
        case .left:
            .string("left")
        case .right:
            .string("right")
        @unknown default:
            nil
        }
    }
}

extension SRWristDetection.CrownOrientation {
    fileprivate var observationValue: ObservationComponent.ValueX? {
        switch self {
        case .left:
            .string("left")
        case .right:
            .string("right")
        @unknown default:
            nil
        }
    }
}
