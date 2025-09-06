//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import ModelsR4


protocol CodingProtocol: Hashable, Sendable {
    static var system: String { get }
    static var version: String? { get }
    
    var rawValue: String { get }
    var displayTitle: String? { get }
}


extension CodingProtocol {
    static var version: String? {
        nil
    }
    
    var system: String {
        Self.system
    }
    
    var version: String? {
        Self.version
    }
}


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


//extension Coding {
//    convenience init(loinc: LOINC) {
//        self.init(
//            code: loinc.code.asFHIRStringPrimitive(),
//            system: "http://loinc.org".asFHIRURIPrimitive()
//        )
//    }
//}


@available(*, deprecated)
func buildObservationComponent(
    loinc: LOINC,
    quantityUnit: String,
    quantityValue: Double
) -> ObservationComponent {
    ObservationComponent.init(code: loinc, value: .quantity(.init(code: loinc, unit: quantityUnit, value: quantityValue)))
//    buildObservationComponent(
//        code: loinc.code,
//        system: "http://loinc.org",
//        quantityUnit: quantityUnit,
//        quantityValue: quantityValue
//    )
}

@available(*, deprecated)
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


extension Coding {
    convenience init<C: CodingProtocol>(system: C.Type = C.self, code: C) {
        self.init(
            code: code.rawValue.asFHIRStringPrimitive(),
            display: code.displayTitle?.asFHIRStringPrimitive(),
            system: code.system.asFHIRURIPrimitive(),
            version: code.version?.asFHIRStringPrimitive()
        )
    }
}

extension CodeableConcept {
    convenience init<C: CodingProtocol>(system: C.Type = C.self, code: C) {
        self.init(coding: [Coding(code: code)])
    }
}


extension ObservationComponent {
    convenience init<C: CodingProtocol>(
        system: C.Type = C.self,
        code: C,
        value: ObservationComponent.ValueX?
    ) {
        self.init(
            code: CodeableConcept(code: code),
            value: value
        )
    }
    
    convenience init<C: CodingProtocol>(
        system: C.Type = C.self,
        code: C,
        quantityUnit: String,
        quantityValue: Double
    ) {
        self.init(code: code, value: .quantity(.init(
            code: code,
            unit: quantityUnit,
            value: quantityValue)
        ))
    }
}


extension Quantity {
    convenience init<C: CodingProtocol>(system: C.Type = C.self, code: C, unit: String, value: Double) {
        self.init(
            code: code.rawValue.asFHIRStringPrimitive(),
            system: code.system.asFHIRURIPrimitive(),
            unit: unit.asFHIRStringPrimitive(),
            value: value.asFHIRDecimalPrimitive()
        )
    }
}
