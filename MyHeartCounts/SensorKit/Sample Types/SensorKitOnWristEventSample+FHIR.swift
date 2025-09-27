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
import SensorKit
import SpeziSensorKit


extension SensorKitOnWristEventSample: HealthObservation {
    var id: UUID {
        var hasher = SensorKitSampleIDHasher()
        hasher.combine(sampleTypeIdentifier)
        hasher.combine(timestamp)
        hasher.combine(onWrist ? 1 : 0)
        hasher.combine(wristLocation.rawValue)
        hasher.combine(crownOrientation.rawValue)
        hasher.combine(onWristDate?.timeIntervalSince1970.bitPattern ?? 0)
        hasher.combine(offWristDate?.timeIntervalSince1970.bitPattern ?? 0)
        return hasher.finalize()
    }
    
    var sampleTypeIdentifier: String {
        Sensor.onWrist.id
    }
    
    func resource(
        withMapping mapping: HKSampleMapping,
        issuedDate: FHIRPrimitive<Instant>?,
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
        if let issuedDate {
            observation.issued = issuedDate
        } else {
            try observation.setIssued(on: .now)
        }
        observation.effective = .dateTime(FHIRPrimitive(try DateTime(date: timestamp)))
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
