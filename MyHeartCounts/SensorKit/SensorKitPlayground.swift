//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
@preconcurrency import SensorKit
import SpeziFoundation
import SpeziViews
import SwiftUI


struct SensorKitPlayground: View {
    @Environment(\.calendar) private var cal
    @Environment(SensorKit.self) private var sensorKit
    
    private let onWristReader = SensorReader(sensor: .onWrist)
    private let ambientLightReader = SensorReader(sensor: .ambientLight)
    private let ambientPressureReader = SensorReader(sensor: .ambientPressure)
    private let heartRateReader = SensorReader(sensor: .heartRate)
    private let pedometerReader = SensorReader(sensor: .pedometer)
    private let wristTemperatureReader = SensorReader(sensor: .wristTemperature)
    private let ppgReader = SensorReader(sensor: .ppg)
    private let ecgReader = SensorReader(sensor: .ecg)
    private let visitsReader = SensorReader(sensor: .visits)
    private let deviceUsageReader = SensorReader(sensor: .deviceUsage)
    
    @State private var viewState: ViewState = .idle
    @State private var ambientLightDevices: [SRDevice] = []
    @State private var ambientLightData: [SRAmbientLightSample] = []
    
    var body: some View {
        Form {
            Section {
                permissionsSection
            }
            Section {
                AsyncButton("Start All", state: $viewState) {
                    for sensor in allSensors {
                        try await sensor.startRecording()
                    }
                }
                AsyncButton("Stop All", state: $viewState) {
                    for sensor in allSensors {
                        try await sensor.stopRecording()
                    }
                }
            }
            SensorReaderSection(reader: onWristReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: ambientLightReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: ambientPressureReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: heartRateReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: pedometerReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: wristTemperatureReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: ppgReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: ecgReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: visitsReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
            SensorReaderSection(reader: deviceUsageReader, viewState: $viewState) { sample in
                Text(verbatim: "\(sample)")
            }
        }
        .viewStateAlert(state: $viewState)
    }
    
    
    @ViewBuilder private var permissionsSection: some View {
        AsyncButton("Request Permissions", state: $viewState) {
            try await sensorKit.requestAccess(to: [
                .onWristState,
                .heartRate,
                .pedometerData,
                .wristTemperature,
                .photoplethysmogram,
                .electrocardiogram,
                .ambientLightSensor,
                .ambientPressure,
                .visits,
                .deviceUsageReport
            ])
        }
        LabeledContent("Permissions", value: "n/a")
    }
    
    private var allSensors: [any SensorReaderProtocol] {
        [
            onWristReader,
            ambientLightReader,
            ambientPressureReader,
            heartRateReader,
            pedometerReader,
            wristTemperatureReader,
            ppgReader,
            ecgReader,
            visitsReader,
            deviceUsageReader
        ]
    }
}


extension SensorKitPlayground {
    private struct SensorReaderSection<Sample: AnyObject & Hashable, SampleRow: View>: View {
        @Environment(\.calendar) private var cal
        let reader: SensorReader<Sample>
        @Binding var viewState: ViewState
        @ViewBuilder let makeRow: (FetchedSensorSample<Sample>) -> SampleRow
        @State private var devices: [SRDevice] = []
        @State private var samples: [FetchedSensorSample<Sample>] = []
        
        var body: some View {
            Section(reader.sensor.displayName) {
                AsyncButton("Fetch Data", state: $viewState) {
                    let devices = try await reader.fetchDevices()
                    var samples: [FetchedSensorSample<Sample>] = []
                    let timeRange = { () -> Range<Date> in
                        let end = cal.date(byAdding: .day, value: -1, to: .now)!
                        let start = cal.date(byAdding: .day, value: -6, to: end)!
                        return start..<end
                    }()
                    for device in devices {
                        samples.append(contentsOf: try await reader.fetch(device: device, timeRange: timeRange))
                    }
                    self.samples = samples
                }
                VStack(alignment: .leading) {
                    Text("Devices:")
                    ForEach(devices, id: \.self) { device in
                        Text("- \(device.description)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                ForEach(samples, id: \.self) { sample in
                    makeRow(sample)
                }
            }
        }
    }
}
