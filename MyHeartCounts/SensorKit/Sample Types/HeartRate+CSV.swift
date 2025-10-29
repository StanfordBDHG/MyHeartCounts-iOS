//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreMotion
import Foundation
import SensorKit
import SpeziSensorKit


extension CMHighFrequencyHeartRateData.SafeRepresentation: CSVAppendableSensorSample {
    static let csvColumns = ["timestamp", "value", "confidence"]
    
    var csvFieldValues: [any CSVWriter.FieldValue] {
        [timestamp, value, confidence.rawValue]
    }
}
