//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all

import Foundation
import ModelsR4


struct UCUM: CodingProtocol {
    nonisolated(unsafe) static let system: FHIRPrimitive<FHIRURI> = "http://unitsofmeasure.org"
    
    nonisolated(unsafe) let code: FHIRPrimitive<FHIRString>
    nonisolated(unsafe) let unit: FHIRPrimitive<FHIRString>
    nonisolated(unsafe) let display: FHIRPrimitive<FHIRString>?
    
    init(code: FHIRPrimitive<FHIRString>, unit: FHIRPrimitive<FHIRString>, display: FHIRPrimitive<FHIRString>? = nil) {
        self.code = code
        self.unit = unit
        self.display = display
    }
}


extension UCUM {
    static let second = Self(code: "s", unit: "s", display: "second")
}


extension Quantity {
    convenience init(unit: UCUM, value: Double?) {
        self.init(
            code: unit.code,
            system: unit.system,
            unit: unit.unit,
            value: value?.asFHIRDecimalPrimitive()
        )
    }
}
