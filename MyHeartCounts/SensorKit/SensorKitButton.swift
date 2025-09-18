//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziSensorKit
import SpeziViews
import SwiftUI


struct SensorKitButton: View {
    // swiftlint:disable attributes
    @Environment(SensorKit.self) private var sensorKit
    @Environment(\.openSettingsApp) private var openSettings
    // swiftlint:enable attributes
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        LabeledButton(
            symbol: .waveformPathEcgRectangle,
            title: isFullyAuthorized ? "Manage SensorKit" : "Enable SensorKit",
            subtitle: "ENABLE_SENSORKIT_SUBTITLE",
            state: $viewState
        ) {
            if isFullyAuthorized {
                // we can't go directly to the SensorKit page, but at least it seems we can go to the settings app.
                openSettings(.settingsApp)
            } else {
                try await sensorKit.requestAccess(to: SensorKit.mhcSensors)
                for sensor in SensorKit.mhcSensors {
                    try await sensor.startRecording()
                }
            }
        }
        .viewStateAlert(state: $viewState)
    }
    
    private var isFullyAuthorized: Bool {
        SensorKit.mhcSensors.allSatisfy {
            $0.authorizationStatus == .authorized
        }
    }
}
