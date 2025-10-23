//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreMotion
import Foundation
import HealthKitOnFHIR
import ModelsR4
import OSLog
import SpeziSensorKit


extension CMPedometerData.SafeRepresentation: HealthObservation {
    var id: UUID {
        var hasher = SensorKitSampleIDHasher()
        hasher.combine(timeRange.lowerBound)
        hasher.combine(timeRange.upperBound)
        hasher.combine(numberOfSteps)
        hasher.combine(distance)
        hasher.combine(floorsAscended)
        hasher.combine(floorsDescended)
        hasher.combine(currentPace)
        hasher.combine(currentCadence)
        hasher.combine(averageActivePace)
        hasher.combine(sampleTypeIdentifier)
        return hasher.finalize()
    }
    
    var sampleTypeIdentifier: String {
        Sensor.pedometer.id
    }
    
    func resource(
        withMapping mapping: HKSampleMapping,
        issuedDate: FHIRPrimitive<Instant>?,
        extensions: [any FHIRExtensionBuilderProtocol]
    ) throws -> ResourceProxy {
        let logger = Logger(subsystem: "edu.stanford.MHC", category: "SensorKit+Pedometer")
        logger.notice("making sample from \(String(describing: self))")
        let observation = Observation(
            code: CodeableConcept(),
            status: FHIRPrimitive(.final)
        )
        observation.id = self.id.uuidString.asFHIRStringPrimitive()
        observation.appendIdentifier(Identifier(id: observation.id))
        observation.effective = try .period(Period(
            end: .init(DateTime(date: timeRange.upperBound)),
            start: .init(DateTime(date: timeRange.lowerBound))
        ))
        if let issuedDate {
            observation.issued = issuedDate
        } else {
            try observation.setIssued(on: .now)
        }
        observation.appendCoding(Coding(code: LOINC.pedometerTrackingPanel))
        observation.appendComponent(.init(
            code: LOINC.pedometerNumStepsInUnspecifiedTime,
            quantityUnit: "count",
            quantityValue: Double(self.numberOfSteps)
        ))
        if let distance {
            observation.appendComponent(.init(
                code: LOINC.pedometerWalkingDistanceInUnspecifiedTime,
                quantityUnit: "m",
                quantityValue: distance
            ))
        }
        if let floorsAscended {
            observation.appendComponent(.init(
                code: LOINC.numberOfFlightsClimbedInReportingPeriod,
                quantityUnit: "count",
                quantityValue: Double(floorsAscended)
            ))
        }
        logger.notice("Missing properties:")
        logger.notice("- floorsAscended: \(String(describing: self.floorsAscended))")
        logger.notice("- floorsDescended: \(String(describing: self.floorsDescended))")
        logger.notice("- currentPace: \(String(describing: self.currentPace))")
        logger.notice("- currentCadence: \(String(describing: self.currentCadence))")
        logger.notice("- averageActivePace: \(String(describing: self.averageActivePace))")
//        floorsAscended
//        floorsDescended
//        currentPace
//        currentCadence
//        averageActivePace
        for builder in extensions {
            try builder.apply(typeErasedInput: self, to: observation)
        }
        try observation.addMHCAppAsSource()
        return .observation(observation)
    }
}
