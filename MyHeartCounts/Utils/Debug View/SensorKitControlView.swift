//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziSensorKit
import SpeziViews
import SwiftUI


struct SensorKitControlView: View {
    @Environment(SensorKit.self)
    private var sensorKit
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        Form {
            Section {
                AsyncButton("Start Recording Data", state: $viewState) {
                    for sensor in SensorKit.mhcSensors {
                        try await sensor.startRecording()
                    }
                }
                AsyncButton("Stop Recording Data", state: $viewState) {
                    for sensor in SensorKit.mhcSensors {
                        try await sensor.stopRecording()
                    }
                }
            }
            Section {
                AsyncButton("Reset Query Anchors", state: $viewState) {
                    @MainActor
                    func imp<Sample>(_ sensor: some AnySensor<Sample>) throws {
                        let sensor = Sensor(sensor)
                        try sensorKit.resetQueryAnchor(for: sensor)
                    }
                    for sensor in SensorKit.allKnownSensors {
                        try imp(sensor)
                    }
                }
            }
        }
        .navigationTitle("SensorKit")
        .viewStateAlert(state: $viewState)
    }
}
