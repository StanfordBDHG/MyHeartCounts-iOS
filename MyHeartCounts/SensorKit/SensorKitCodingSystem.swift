//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziSensorKit


struct SensorKitCodingSystem: CodingProtocol {
    static var system: String { "https://developer.apple.com/documentation/sensorkit" }
    
    let rawValue: String
    let displayTitle: String?
    
    init(_ code: String, displayTitle: String? = nil) {
        self.rawValue = code
        self.displayTitle = displayTitle
    }
    
    init(_ sensor: Sensor<some Any>) {
        self.init(sensor.id, displayTitle: sensor.displayName)
    }
}
