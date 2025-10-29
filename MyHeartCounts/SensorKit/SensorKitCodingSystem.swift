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
    
    let code: String
    let display: String?
    
    init(_ code: String, display: String? = nil) {
        self.code = code
        self.display = display
    }
    
    init(_ sensor: Sensor<some Any>) {
        self.init(sensor.id, display: sensor.displayName)
    }
    
    func property(_ name: String, display: String? = nil) -> Self {
        Self("\(code)/\(name)", display: display)
    }
}
