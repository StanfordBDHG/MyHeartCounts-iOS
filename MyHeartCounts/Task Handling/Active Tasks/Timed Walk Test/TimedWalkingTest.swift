//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable type_contents_order

import CoreHaptics
import CoreMotion
import Foundation
import OSLog
import Spezi
import SpeziFoundation
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
        fileprivate var completeSessionTask: Task<TimedWalkingTestResult?, any Error>?
        
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
        }
        
        case unableToStart(StartFailureReason)
        case other(any Error)
        
        var errorDescription: String? {
            switch self {
            case .unableToStart(.alreadyActive):
                "Another Timed Walking Test is already active"
            case .unableToStart(.missingSensorPermissions):
                "There are missing Motion Sensor permissions"
            case .other(let error):
                "\(error)"
            }
        }
    }
    
    // swiftlint:disable attributes
    @ObservationIgnored @StandardActor private var standard: MyHeartCountsStandard
    @ObservationIgnored @Dependency(WatchConnection.self) private var watchManager
    // swiftlint:enable attributes
    
    private let hapticEngine = try? CHHapticEngine()
    nonisolated(unsafe) private let pedometer = CMPedometer()
    nonisolated(unsafe) private let altimeter = CMAltimeter()
    
    private(set) var state: State = .idle
    /// The most recent Timed Walking Test result
    private(set) var mostRecentResult: TimedWalkingTestResult?
    
    private(set) var absoluteAltitudeMeasurements: [AbsoluteAltitudeMeasurement] = []
    private(set) var relativeAltitudeMeasurements: [RelativeAltitudeMeasurement] = []
    private(set) var pedometerMeasurements: [PedometerData] = []
    private(set) var pedometerEvents: [PedometerEvent] = []
    
    func start(_ test: TimedWalkingTestConfiguration) async throws(TestError) -> TimedWalkingTestResult? {
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
            try await watchManager.startWorkoutOnWatch(for: test)
            logger.notice("Successfully launched watch app")
        } catch {
            // we still continue if the watch app failed to launch.
            logger.notice("Failed to launch watch app: \(error)")
        }
        let startInstant = ContinuousClock.Instant.now
        let session = ActiveSession(test: test, startDate: .now)
        state = .testActive(session)
        startPhoneSensorDataCollection(for: session)
        let sessionTask = Task {
            #if targetEnvironment(simulator)
            // Enable a simple testing of the UI on the simulator.
            try await Task.sleep(until: startInstant.advanced(by: Duration.seconds(5)))
            #else
            try await Task.sleep(until: startInstant.advanced(by: test.duration))
            #endif
            return try await stop()
        }
        session.completeSessionTask = sessionTask
        let result = await sessionTask.result
        switch result {
        case .success(let result):
            return result
        case .failure(let error):
            throw .other(error)
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
            try? vibrate()
            var result = session.inProgressResult
            #if targetEnvironment(simulator)
            result = TimedWalkingTestResult(
                id: UUID(),
                test: .sixMinuteWalkTest,
                startDate: .now.addingTimeInterval(-360),
                endDate: .now,
                numberOfSteps: 624,
                distanceCovered: 842
            )
            #else
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
            #endif
            try? await standard.uploadHealthObservation(result)
            return result
        }
    }
    
    
    private func vibrate() throws {
        guard let engine = hapticEngine else {
            return
        }
        let tapDuration: TimeInterval = 0.15
        let pattern = try CHHapticPattern(
            events: (0..<5).map { idx in
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
                    ],
                    relativeTime: TimeInterval(idx) * tapDuration * 2,
                    duration: tapDuration
                )
            },
            parameters: []
        )
        let player = try engine.makePlayer(with: pattern)
        _Concurrency.Task {
            try await engine.start()
            try player.start(atTime: 0)
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
    static func authorizationStatus() -> CMAuthorizationStatus {
        CMPedometer.authorizationStatus()
    }
    
    /// Requests access to the "Motion and Fitness" data.
    ///
    /// If the user has already granted or denied access in the past, or access is otherwise impossible, this function returns immediately.
    /// Otherwise (i.e., if the user hasn't been asked yet), it will prompt the user to grant access and return then.
    ///
    /// - returns: A boolean indicating whether the request was successful and we now have access.
    static func requestMotionDataAccess() async -> Bool {
        // we're using the pedometer here, but it doesn't really matter since requesting access to that will also give us access to the other Motion sensors (eg: altimeter)
        switch CMPedometer.authorizationStatus() {
        case .authorized:
            true
        case .denied, .restricted:
            false
        case .notDetermined:
            await withCheckedContinuation { continuation in
                // ISSUE: we use the `queryPedometerData` function to trigger the permission prompt.
                // But: The completion handler will only get called if the pedometer object is still
                // around by the time the user grants/denies us the permission.
                // Meaning that we need to somehow extend the lifetime of the pedometer object.
                // We do this by capturing it in the closure, and then setting it to nil once we've received the callback.
                nonisolated(unsafe) var pedometer: CMPedometer? = CMPedometer()
                pedometer!.queryPedometerData(from: .now, to: .now) { @Sendable _, error in // swiftlint:disable:this force_unwrapping
                    // we simply assume that the absence of an error implies that the authorization was successfully granted
                    continuation.resume(returning: error == nil || CMMotionManager.authorizationStatus() == .authorized)
                    pedometer = nil
                }
            }
        @unknown default:
            false
        }
    }
}
