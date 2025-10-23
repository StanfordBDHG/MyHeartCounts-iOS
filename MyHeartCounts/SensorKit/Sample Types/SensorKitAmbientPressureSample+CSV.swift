//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreMotion
import Foundation
import SpeziSensorKit


extension CMRecordedPressureData.SafeRepresentation: CSVAppendableSensorSample {
    static let csvColumns = ["timestamp", "identifier", "pressure", "temperature"]
    
    var csvFieldValues: [any CSVFieldValue] {
        [
            timestamp,
            identifier,
            pressure.value,
            temperature.value
        ]
    }
}
