//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MyHeartCountsShared
import SensorKit
import SpeziSensorKit


extension SRAmbientLightSample.SafeRepresentation: CSVAppendableSensorSample {
    static let csvColumns = ["timestamp", "lux", "placement", "chromacityX", "chromacityY"]
    
    var csvFieldValues: [any CSVWriter.FieldValue] {
        [
            timestamp,
            lux.value,
            placement.description,
            chromacity.x,
            chromacity.y
        ]
    }
}
