//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreMotion
import Foundation
import MyHeartCountsShared
import SpeziSensorKit


extension CMPedometerData.SafeRepresentation: CSVAppendableSensorSample {
    static let csvColumns = [
        "start", "end", "steps", "distance", "floorsUp", "floorsDown", "currentPace", "currentCadence", "avgActivePace"
    ]
    
    var csvFieldValues: [any CSVWriter.FieldValue] {
        [
            timeRange.lowerBound,
            timeRange.upperBound,
            numberOfSteps,
            distance,
            floorsAscended,
            floorsDescended,
            currentPace,
            currentCadence,
            averageActivePace
        ]
    }
}
