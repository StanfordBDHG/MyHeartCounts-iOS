//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable type_contents_order

import CoreMotion
import Foundation
import HealthKit
import MyHeartCountsShared
import Spezi
import SpeziHealthKit
import SpeziStudyDefinition


@Observable
@MainActor
final class TimedWalkingTest: Module, EnvironmentAccessible, Sendable {
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
        private(set) var inProgressResult: TimedWalkingTestResult
        /// The `Task` that waits for the session's duration to pass, and then ends the session
        fileprivate var completeSessionTask: Task<Void, any Error>?
        
        var startDate: Date {
            inProgressResult.startDate
        }
        
        init(test: TimedWalkingTestConfiguration, startDate: Date) {
            self.inProgressResult = .init(
                id: UUID(),
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
    
    // swiftlint:disable attributes
    @ObservationIgnored @StandardActor private var standard: MyHeartCountsStandard
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(WatchConnection.self) private var watchManager
    @ObservationIgnored @Application(\.spezi) private var spezi
    // swiftlint:enable attributes
    
    nonisolated(unsafe) private let motionManager = CMMotionManager()
    nonisolated(unsafe) private let pedometer = CMPedometer()
    nonisolated(unsafe) private let altimeter = CMAltimeter()
    
    private(set) var state: State = .idle
    /// The most recent Timed Walking Test result
    private(set) var mostRecentResult: TimedWalkingTestResult?
    
    private(set) var absoluteAltitudeMeasurements: [AbsoluteAltitudeMeasurement] = []
    private(set) var relativeAltitudeMeasurements: [RelativeAltitudeMeasurement] = []
    private(set) var pedometerMeasurements: [PedometerData] = []
    private(set) var pedometerEvents: [PedometerEvent] = []
    
    func start(_ test: TimedWalkingTestConfiguration) async throws(TestError) {
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
            try await watchManager.startWorkoutOnWatch(for: test.kind)
            logger.notice("Successfully launched watch app")
        } catch {
            // we still continue if the watch workout failed.
            logger.notice("Failed to start watch workout: \(error)")
        }
        let startInstant = ContinuousClock.Instant.now
        let session = ActiveSession(test: test, startDate: .now)
        state = .testActive(session)
        startPhoneSensorDataCollection(for: session)
        session.completeSessionTask = Task {
            try await Task.sleep(until: startInstant.advanced(by: test.duration))
            if let result = try await stop() {
                await MainActor.run {
                    self.mostRecentResult = result
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
            session.completeSessionTask?.cancel()
            stopPhoneSensorDataCollection()
            try? await watchManager.stopWorkoutOnWatch()
            var result = session.inProgressResult
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                pedometer.queryPedometerData(from: result.startDate, to: result.endDate) { @Sendable data, error in
                    guard let data else {
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume() // hmmm
                        }
                        return
                    }
                    let numSteps = data.numberOfSteps.intValue
                    let distance = data.distance?.doubleValue ?? 0
                    Task { @MainActor in
                        result.numberOfSteps = numSteps
                        result.distanceCovered = distance
                    }
                    continuation.resume()
                }
            }
            try? await standard.uploadHealthObservation(result)
            return result
        }
    }
}


extension TimedWalkingTest {
    private func startPhoneSensorDataCollection(for session: ActiveSession) {
        let queue = OperationQueue()
        absoluteAltitudeMeasurements.removeAll(keepingCapacity: true)
        altimeter.startAbsoluteAltitudeUpdates(to: queue) { @Sendable (data: CMAbsoluteAltitudeData?, _) in
            guard let data else {
                return
            }
            let measurement = AbsoluteAltitudeMeasurement(data)
            Task { @MainActor in
                self.absoluteAltitudeMeasurements.append(measurement)
            }
        }
        relativeAltitudeMeasurements.removeAll(keepingCapacity: true)
        altimeter.startRelativeAltitudeUpdates(to: queue) { @Sendable (data: CMAltitudeData?, _) in
            guard let data else {
                return
            }
            let measurement = RelativeAltitudeMeasurement(data)
            Task { @MainActor in
                self.relativeAltitudeMeasurements.append(measurement)
            }
        }
        pedometerMeasurements.removeAll(keepingCapacity: true)
        pedometer.startUpdates(from: session.startDate) { @Sendable (data: CMPedometerData?, _) in
            guard let data else {
                return
            }
            let measurement = PedometerData(data)
            Task { @MainActor in
                self.pedometerMeasurements.append(measurement)
            }
        }
        pedometerEvents.removeAll(keepingCapacity: true)
        pedometer.startEventUpdates { @Sendable (event: CMPedometerEvent?, _) in
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
