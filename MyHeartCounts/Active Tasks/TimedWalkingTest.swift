//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order type_contents_order all

import CoreMotion
import Foundation
//import SensorKit // ???
import Spezi


struct TimedWalkingTest: Codable, Hashable, Sendable {
    let duration: Duration
}


@Observable
@MainActor
final class TimedWalkingTestConductor: Module, EnvironmentAccessible, Sendable {
    enum State: Hashable, Sendable {
        case idle
        case testActive(TimedWalkingTest, InProgressTestInfo)
        
        var isActive: Bool {
            switch self {
            case .testActive: true
            case .idle: false
            }
        }
    }
    
    @MainActor
    final class InProgressTestInfo: Hashable, Sendable {
        let startDate: Date
        
        init(startDate: Date) {
            self.startDate = startDate
        }
        
        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
        
        nonisolated static func == (lhs: InProgressTestInfo, rhs: InProgressTestInfo) -> Bool {
            ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }
    }
    
    enum TestError: Error, LocalizedError {
        enum StartFailureReason {
            case missingSensorPermissions
            case alreadyActive
        }
        
        case unableToStart(StartFailureReason)
        
        var errorDescription: String? {
            switch self {
            case .unableToStart(.alreadyActive):
                "Another Timed Walking Test is already active"
            case .unableToStart(.missingSensorPermissions):
                "There are missing Motion Sensor permissions"
            }
        }
    }
    
    nonisolated(unsafe) private let motionManager = CMMotionManager()
    nonisolated(unsafe) private let pedometer = CMPedometer()
    nonisolated(unsafe) private let altimeter = CMAltimeter()
    
    private(set) var state: State = .idle
    private(set) var absoluteAltitudeMeasurements: [AbsoluteAltitudeMeasurement] = []
    private(set) var relativeAltitudeMeasurements: [RelativeAltitudeMeasurement] = []
    private(set) var pedometerMeasurements: [PedometerData] = []
    private(set) var pedometerEvents: [PedometerEvent] = []
    
    func conduct(_ test: TimedWalkingTest) async throws(TestError) {
        switch state {
        case .idle:
            break
        case .testActive:
            throw .unableToStart(.alreadyActive)
        }
        guard await CMMotionManager.requestMotionDataAccess() else {
            throw .unableToStart(.missingSensorPermissions)
        }
        let progress = InProgressTestInfo(startDate: .now)
        state = .testActive(test, progress)
        let queue = OperationQueue()
        altimeter.startAbsoluteAltitudeUpdates(to: queue) { @Sendable (data: CMAbsoluteAltitudeData?, error: (any Error)?) in
            print(data, error)
            guard let data else {
                return
            }
            let measurement = AbsoluteAltitudeMeasurement(data)
            Task { @MainActor in
                self.absoluteAltitudeMeasurements.append(measurement)
            }
        }
        altimeter.startRelativeAltitudeUpdates(to: queue) { @Sendable (data: CMAltitudeData?, error: (any Error)?) in
            print(data, error)
            guard let data else {
                return
            }
            let measurement = RelativeAltitudeMeasurement(data)
            Task { @MainActor in
                self.relativeAltitudeMeasurements.append(measurement)
            }
        }
        pedometer.startUpdates(from: progress.startDate) { @Sendable (data: CMPedometerData?, error: (any Error)?) in
            print(data, error)
            guard let data else {
                return
            }
            let measurement = PedometerData(data)
            Task { @MainActor in
                self.pedometerMeasurements.append(measurement)
            }
        }
        pedometer.startEventUpdates { @Sendable (event: CMPedometerEvent?, error: (any Error)?) in
            print(event, error)
            guard let event else {
                return
            }
            let trackedEvent = PedometerEvent(event)
            Task { @MainActor in
                self.pedometerEvents.append(trackedEvent)
            }
        }
    }
}


// MARK: Permission Handling

extension TimedWalkingTestConductor {
    private func requestAllPermissions() async throws {
        // motionManager.
    }
}


extension CMMotionManager {
    static func requestMotionDataAccess() async -> Bool {
        // we're using the pedometer here, but it doesn't really matter since requesting access to that will also give us access to the other Motion sensors (eg: altimeter)
        switch CMPedometer.authorizationStatus() {
        case .authorized:
            true
        case .denied, .restricted:
            false
        case .notDetermined:
            await withCheckedContinuation { continuation in
                CMPedometer().queryPedometerData(from: .now, to: .now) { _, error in
                    // we simply assume that the absence of an error implies that the authorization was successfully granted.
                    continuation.resume(returning: error == nil)
                }
            }
        @unknown default:
            false
        }
    }
}


// MARK: Other

extension CMPedometerEventType {
    var displayTitle: String {
        switch self {
        case .pause: "Pause"
        case .resume: "Resume"
        @unknown default: "unknown<\(rawValue)>"
        }
    }
}
