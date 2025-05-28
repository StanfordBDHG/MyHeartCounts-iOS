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
import HealthKit
import MyHeartCountsShared
//import SensorKit // ???
import Spezi
import SpeziHealthKit
import WatchConnectivity


@Observable
@MainActor
final class TimedWalkingTestConductor: Module, EnvironmentAccessible, Sendable {
    enum State: Hashable, Sendable {
        case idle
        case testActive(ActiveSession)
        
        var isActive: Bool {
            switch self {
            case .testActive: true
            case .idle: false
            }
        }
    }
    
    @Observable
    @MainActor
    final class ActiveSession: Hashable, Sendable {
        private(set) var preliminaryResults: TimedWalkingTestResult
        
        var startDate: Date {
            preliminaryResults.startDate
        }
        
        init(test: TimedWalkingTest, startDate: Date) {
            self.preliminaryResults = .init(
                test: test,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(test.duration.timeInterval),
                numberOfSteps: 0,
                distanceCovered: 0
            )
        }
        
        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
        
        nonisolated static func == (lhs: ActiveSession, rhs: ActiveSession) -> Bool {
            ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }
    }
    
    enum TestError: Error, LocalizedError {
        enum StartFailureReason {
            case missingSensorPermissions
            case alreadyActive
            //            case other
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
    
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(WatchConnection.self) private var watchConnection
    
    nonisolated(unsafe) private let motionManager = CMMotionManager()
    nonisolated(unsafe) private let pedometer = CMPedometer()
    nonisolated(unsafe) private let altimeter = CMAltimeter()
    
    private(set) var state: State = .idle
    private(set) var absoluteAltitudeMeasurements: [AbsoluteAltitudeMeasurement] = []
    private(set) var relativeAltitudeMeasurements: [RelativeAltitudeMeasurement] = []
    private(set) var pedometerMeasurements: [PedometerData] = []
    private(set) var pedometerEvents: [PedometerEvent] = []
    private(set) var tmpMostRecentResult: TimedWalkingTestResult?
    
    
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
        do {
            logger.notice("isWatchConnectivitySupported: \(WCSession.isSupported())")
            try await watchConnection.startWorkoutOnWatch(for: test.kind)
            logger.notice("Successfully launched watch app")
        } catch {
            // we still continue if the watch workout failed.
            logger.notice("Failed to start watch workout: \(error)")
        }
        let startInstant = ContinuousClock.Instant.now
        let session = ActiveSession(test: test, startDate: .now)
        state = .testActive(session)
        startPhoneSensorDataCollection(for: session)
        Task {
            try await Task.sleep(until: startInstant.advanced(by: test.duration))
            if let result = try await stop() {
                await MainActor.run {
                    self.tmpMostRecentResult = result
                }
            }
        }
    }
    
    
    func stop() async throws -> TimedWalkingTestResult? {
        switch state {
        case .idle:
            return nil
        case .testActive(let session):
            defer {
                state = .idle
            }
            stopPhoneSensorDataCollection()
            try await watchConnection.stopWorkoutOnWatch()
            var results = session.preliminaryResults
            results.numberOfSteps = pedometerMeasurements.reduce(0) { $0 + $1.numberOfSteps }
            results.distanceCovered = pedometerMeasurements.reduce(0) { $0 + ($1.distance ?? 0) }
            return results
        }
    }
}


extension TimedWalkingTestConductor {
    private func startPhoneSensorDataCollection(for session: ActiveSession) {
        let queue = OperationQueue()
        absoluteAltitudeMeasurements.removeAll(keepingCapacity: true)
        altimeter.startAbsoluteAltitudeUpdates(to: queue) { @Sendable (data: CMAbsoluteAltitudeData?, error: (any Error)?) in
            guard let data else {
                return
            }
            let measurement = AbsoluteAltitudeMeasurement(data)
            Task { @MainActor in
                self.absoluteAltitudeMeasurements.append(measurement)
            }
        }
        relativeAltitudeMeasurements.removeAll(keepingCapacity: true)
        altimeter.startRelativeAltitudeUpdates(to: queue) { @Sendable (data: CMAltitudeData?, error: (any Error)?) in
            guard let data else {
                return
            }
            let measurement = RelativeAltitudeMeasurement(data)
            Task { @MainActor in
                self.relativeAltitudeMeasurements.append(measurement)
            }
        }
        pedometerMeasurements.removeAll(keepingCapacity: true)
        pedometer.startUpdates(from: session.startDate) { @Sendable (data: CMPedometerData?, error: (any Error)?) in
            guard let data else {
                return
            }
            let measurement = PedometerData(data)
            Task { @MainActor in
                self.pedometerMeasurements.append(measurement)
            }
        }
        pedometerEvents.removeAll(keepingCapacity: true)
        pedometer.startEventUpdates { @Sendable (event: CMPedometerEvent?, error: (any Error)?) in
            guard let event else {
                return
            }
            let trackedEvent = PedometerEvent(event)
            Task { @MainActor in
                self.pedometerEvents.append(trackedEvent)
            }
        }
    }
    
    private func stopPhoneSensorDataCollection() {
        altimeter.stopAbsoluteAltitudeUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
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
