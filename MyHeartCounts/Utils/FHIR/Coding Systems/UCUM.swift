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
    static let system = "http://unitsofmeasure.org"
    
    let code: String
    let unit: String
    let display: String?
    
    init(code: String, unit: String, display: String? = nil) {
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
            code: unit.code.asFHIRStringPrimitive(),
            system: unit.system.asFHIRURIPrimitive(),
            unit: unit.unit.asFHIRStringPrimitive(),
            value: value?.asFHIRDecimalPrimitive()
        )
    }
}
