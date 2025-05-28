//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import CoreMotion
import Foundation
import MyHeartCountsShared
import Spezi
import SpeziViews
import SwiftUI


struct TimedWalkingTestView: View {
    @Environment(\.openAppSettings)
    private var openAppSettings
    
    @Environment(TimedWalkingTestConductor.self)
    private var conductor
    
    private let test: TimedWalkingTest = .init(duration: .minutes(2), kind: .walking)
    
    @State private var viewState: ViewState = .idle
    @State private var showPermissionsErrorSection = false
    
    var body: some View {
        Form {
            if showPermissionsErrorSection {
                permissionsErrorSection
            }
            Section {
                content
            }
            if let result = conductor.tmpMostRecentResult {
                Section {
                    LabeledContent("Kind", value: result.test.kind.displayTitle)
                    LabeledContent("Duration", value: result.test.duration.formatted())
                    LabeledContent("Number of Steps", value: result.numberOfSteps, format: .number)
                    LabeledContent("Distance Covered", value: Measurement<UnitLength>(value: result.distanceCovered, unit: .meters), format: .measurement(width: .abbreviated))
                }
            }
            
//            if let measurement = conductor.absoluteAltitudeMeasurements.last {
//                Section("Altitude (absolute)") {
//                    LabeledContent("timestamp", value: Duration.seconds(measurement.timestamp).formatted())
//                    LabeledContent("timestamp", value: Duration.seconds(measurement.timestamp).formatted())
//                    LabeledContent("altitude", value: measurement.altitude, format: .number)
//                    LabeledContent("accuracy", value: measurement.accuracy, format: .number)
//                    LabeledContent("precision", value: measurement.precision, format: .number)
//                }
//            }
//            if let measurement = conductor.relativeAltitudeMeasurements.last {
//                Section("Altitude (relative)") {
//                    LabeledContent("timestamp", value: Duration.seconds(measurement.timestamp).formatted())
//                    LabeledContent("altitude", value: measurement.altitude, format: .number)
//                    LabeledContent("pressure", value: measurement.pressure, format: .number)
//                }
//            }
//            Section("StepCountEvents") {
//                ForEach(conductor.pedometerEvents, id: \.self) { event in
//                    HStack {
//                        Text(event.type.displayTitle)
//                        Spacer()
//                        Text(event.date, format: .iso8601)
//                            .font(.footnote)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//            ForEach(conductor.pedometerMeasurements, id: \.self) { (measurement: PedometerData) in
//                Section {
//                    LabeledContent("startDate", value: measurement.startDate, format: .dateTime)
//                    LabeledContent("endDate", value: measurement.endDate, format: .dateTime)
//                    LabeledContent("numberOfSteps", value: measurement.numberOfSteps, format: .number)
//                    if let distance = measurement.distance {
//                        LabeledContent("distance", value: distance, format: .number)
//                    }
//                    if let floorsAscended = measurement.floorsAscended {
//                        LabeledContent("floorsAscended", value: floorsAscended, format: .number)
//                    }
//                    if let floorsDescended = measurement.floorsDescended {
//                        LabeledContent("floorsDescended", value: floorsDescended, format: .number)
//                    }
//                    if let currentPace = measurement.currentPace {
//                        LabeledContent("currentPace", value: currentPace, format: .number)
//                    }
//                    if let currentCadence = measurement.currentCadence {
//                        LabeledContent("currentCadence", value: currentCadence, format: .number)
//                    }
//                    if let averageActivePace = measurement.averageActivePace {
//                        LabeledContent("averageActivePace", value: averageActivePace, format: .number)
//                    }
//                }
//            }
        }
        .viewStateAlert(state: $viewState)
        .interactiveDismissDisabled(conductor.state.isActive)
        .onAppear {
            showPermissionsErrorSection = [
                CMPedometer.authorizationStatus() == .denied,
                CMAltimeter.authorizationStatus() == .denied
                // TODO add more!
            ].contains(true)
        }
    }
    
    @ViewBuilder private var content: some View { // TODO ugh
        switch conductor.state {
        case .idle:
            AsyncButton("Start", state: $viewState) {
                try await conductor.conduct(test)
            }
        case .testActive(let session):
            let timerInterval = session.preliminaryResults.startDate...session.preliminaryResults.endDate
            HStack {
                Text("Time Elapsed")
                Spacer()
                Text(timerInterval: timerInterval, countsDown: false)
            }
            LabeledContent("Time Remaining") {
                Text(timerInterval: timerInterval)
            }
            AsyncButton("Stop", state: $viewState) {
                try await conductor.stop()
            }
        }
    }
    
    
    @ViewBuilder private var permissionsErrorSection: some View {
        Section {
            HStack {
                Image(systemSymbol: .exclamationmarkTriangle)
//                    .resizable()
//                    .frame(width: 27, height: 27)
                    .accessibilityLabel("Error Symbol")
                    .foregroundStyle(.red)
                VStack(alignment: .leading) {
                    Text("Missing Sensor Access Permissions")
                        .font(.headline)
                    Text("You need to grant MyHeart Counts access to Motion Data")
                        .font(.subheadline)
                }
            }
            Button {
                openAppSettings()
            } label: {
                Text("Open Settings")
                // TODO: align horizontally w/ text in row above!
            }
        }
    }
}


extension TimedWalkingTest.Kind {
    var displayTitle: String {
        switch self {
        case .walking: "Walking"
        case .running: "Running"
        }
    }
}
