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


extension TimedWalkingTestResult {
    func resource(
        withMapping: HealthKitOnFHIR.HKSampleMapping,
        issuedDate: ModelsR4.FHIRPrimitive<ModelsR4.Instant>?
    ) throws -> ModelsR4.ResourceProxy {
        try .observation(fhirObservation(issuedDate: issuedDate))
    }
    
    
    func fhirObservation(issuedDate: ModelsR4.FHIRPrimitive<ModelsR4.Instant>?) throws -> Observation {
        let observation = Observation(
            code: CodeableConcept(),
            status: FHIRPrimitive(.final)
        )
        // Set basic elements applicable to all observations
        observation.id = self.id.uuidString.asFHIRStringPrimitive()
        observation.appendIdentifier(Identifier(id: observation.id))
        try observation.setEffective(startDate: self.startDate, endDate: self.endDate, timeZone: .current)
        if let issuedDate {
            observation.issued = issuedDate
        } else {
            try observation.setIssued(on: .now)
        }
        // Add LOINC code dependent on the walk test duration.
        let loincSystem = "http://loinc.org".asFHIRURIPrimitive()
        if test.duration == .minutes(6) {
            observation.appendCoding(
                Coding(
                    code: "62619-2".asFHIRStringPrimitive(),
                    system: loincSystem
                )
            )
        } else {
            observation.appendCoding(
                Coding(
                    code: "55430-3".asFHIRStringPrimitive(),
                    system: loincSystem
                )
            )
        }
        observation.appendComponent(
            builObservationComponent(
                code: "55423-8",
                system: "http://loinc.org",
                unit: "steps",
                value: Double(numberOfSteps)
            )
        )
        observation.appendComponent(
            builObservationComponent(
                code: "55430-3",
                system: "http://loinc.org",
                unit: "m",
                value: distanceCovered
            )
        )
        return observation
    }
}

private func builObservationComponent(code: String, system: String, unit: String, value: Double) -> ObservationComponent {
    ObservationComponent(
        code: CodeableConcept(coding: [Coding(code: code.asFHIRStringPrimitive(), system: system.asFHIRURIPrimitive())]),
        value: .quantity(.init(
            code: code.asFHIRStringPrimitive(),
            system: system.asFHIRURIPrimitive(),
            unit: unit.asFHIRStringPrimitive(),
            value: value.asFHIRDecimalPrimitive()
        ))
    )
}
