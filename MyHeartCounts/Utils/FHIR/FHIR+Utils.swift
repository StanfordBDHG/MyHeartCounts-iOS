//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ModelsR4


protocol CodingProtocol: Hashable, Sendable {
    static var system: String { get }
    static var version: String? { get }
    
    var code: String { get }
    var display: String? { get }
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

extension Coding {
    // periphery:ignore:parameters system
    convenience init<C: CodingProtocol>(system: C.Type = C.self, code: C) {
        self.init(
            code: code.code.asFHIRStringPrimitive(),
            display: code.display?.asFHIRStringPrimitive(),
            system: code.system.asFHIRURIPrimitive(),
            version: code.version?.asFHIRStringPrimitive()
        )
    }
}

extension CodeableConcept {
    convenience init<C: CodingProtocol>(system: C.Type = C.self, code: C) {
        self.init(coding: [Coding(system: system, code: code)])
    }
}


extension ObservationComponent {
    convenience init<C: CodingProtocol>(
        system: C.Type = C.self,
        code: C,
        value: ObservationComponent.ValueX?
    ) {
        self.init(
            code: CodeableConcept(system: system, code: code),
            value: value
        )
    }
    
    convenience init<C: CodingProtocol>(
        system: C.Type = C.self,
        code: C,
        quantityUnit: String,
        quantityValue: Double
    ) {
        self.init(
            code: code,
            value: .quantity(.init(
                system: system,
                code: code,
                unit: quantityUnit,
                value: quantityValue
            ))
        )
    }
}


extension Quantity {
    // periphery:ignore:parameters system
    convenience init<C: CodingProtocol>(system: C.Type = C.self, code: C, unit: String, value: Double) {
        self.init(
            code: code.code.asFHIRStringPrimitive(),
            system: code.system.asFHIRURIPrimitive(),
            unit: unit.asFHIRStringPrimitive(),
            value: value.asFHIRDecimalPrimitive()
        )
    }
}
