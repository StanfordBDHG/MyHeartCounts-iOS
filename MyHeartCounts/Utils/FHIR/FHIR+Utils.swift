//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ModelsR4


extension ModelsR4.Resource: @retroactive Identifiable {}

extension ModelsR4.ResourceProxy {
    var observation: Observation? {
        switch self {
        case .observation(let observation):
            observation
        default:
            nil
        }
    }
}


extension Coding {
    convenience init(loinc: LOINC) {
        self.init(
            code: loinc.code.asFHIRStringPrimitive(),
            system: "http://loinc.org".asFHIRURIPrimitive()
        )
    }
}


func buildObservationComponent(
    loinc: LOINC,
    quantityUnit: String,
    quantityValue: Double
) -> ObservationComponent {
    buildObservationComponent(
        code: loinc.code,
        system: "http://loinc.org",
        quantityUnit: quantityUnit,
        quantityValue: quantityValue
    )
}

func buildObservationComponent(
    code: String,
    system: String,
    quantityUnit: String,
    quantityValue: Double
) -> ObservationComponent {
    ObservationComponent(
        code: CodeableConcept(coding: [Coding(code: code.asFHIRStringPrimitive(), system: system.asFHIRURIPrimitive())]),
        value: .quantity(.init(
            code: code.asFHIRStringPrimitive(),
            system: system.asFHIRURIPrimitive(),
            unit: quantityUnit.asFHIRStringPrimitive(),
            value: quantityValue.asFHIRDecimalPrimitive()
        ))
    )
}
