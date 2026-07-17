//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class UnitOxygenConsumption: Dimension, @unchecked Sendable {
    static let mlPerKgPerMin = UnitOxygenConsumption(
        symbol: "mL/kg·min",
        converter: UnitConverterLinear(coefficient: 1)
    )
    
    override class func baseUnit() -> UnitOxygenConsumption {
        mlPerKgPerMin
    }
}
