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
import Spezi
import SpeziHealthKit


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
        private(set) var preliminaryResults: TimedWalkingTestResult
        /// The `Task` that waits for the session's duration to pass, and then ends the session
        fileprivate var completeSessionTask: Task<Void, any Error>?
        
        var startDate: Date {
            preliminaryResults.startDate
        }
        
        init(test: TimedWalkingTestConfiguration, startDate: Date) {
            self.preliminaryResults = .init(
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
    
    
    @ObservationIgnored @StandardActor private var standard: MyHeartCountsStandard
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(WatchConnection.self) private var watchManager
    
    @ObservationIgnored @Application(\.spezi) private var spezi
    
    nonisolated(unsafe) private let motionManager = CMMotionManager()
    nonisolated(unsafe) private let pedometer = CMPedometer()
    nonisolated(unsafe) private let altimeter = CMAltimeter()
    
    
    struct Event: Hashable, Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let desc: String
    }
    
    private(set) var dbg_eventLog: [Event] = []
    private(set) var state: State = .idle
    private(set) var absoluteAltitudeMeasurements: [AbsoluteAltitudeMeasurement] = []
    private(set) var relativeAltitudeMeasurements: [RelativeAltitudeMeasurement] = []
    private(set) var pedometerMeasurements: [PedometerData] = []
    private(set) var pedometerEvents: [PedometerEvent] = []
    private(set) var tmpMostRecentResult: TimedWalkingTestResult?
    
    
    nonisolated private func logEvent(_ event: String) {
        Task { @MainActor in
            dbg_eventLog.append(.init(date: .now, desc: event))
        }
    }
    
    func conduct(_ test: TimedWalkingTestConfiguration) async throws(TestError) {
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
//            logger.notice("isWatchConnectivitySupported: \(WCSession.isSupported())")
            logEvent("will start workout on watch")
            try await watchManager.startWorkoutOnWatch(for: test.kind)
            logEvent("did start workout on watch")
            logger.notice("Successfully launched watch app")
        } catch {
            // we still continue if the watch workout failed.
            logger.notice("Failed to start watch workout: \(error)")
        }
        let startInstant = ContinuousClock.Instant.now
        let session = ActiveSession(test: test, startDate: .now)
        state = .testActive(session)
        logEvent("will start phone data collection")
        startPhoneSensorDataCollection(for: session)
        logEvent("did start phone data collection")
        session.completeSessionTask = Task { [unowned session] in
            logEvent("will wait to stop session")
            try await Task.sleep(until: startInstant.advanced(by: test.duration))
            logEvent("will stop session")
            if let result = try await stop() {
                await MainActor.run {
                    self.tmpMostRecentResult = result
                }
            }
            logEvent("did stop session")
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
            logEvent("will stop phone data collection")
            stopPhoneSensorDataCollection()
            logEvent("will stop watch workout")
            try? await watchManager.stopWorkoutOnWatch()
            var results = session.preliminaryResults
//            results.numberOfSteps = pedometerMeasurements.reduce(0) { $0 + $1.numberOfSteps }
//            results.distanceCovered = pedometerMeasurements.reduce(0) { $0 + ($1.distance ?? 0) }
            logEvent("will fetch pedometer data and add to results")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                pedometer.queryPedometerData(from: results.startDate, to: results.endDate) { @Sendable data, error in
                    self.logEvent("pedometer callback (\(data), \(error))")
                    guard let data else {
                        self.logEvent("no pedometer data :/ (error: \(error))")
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume() // hmmm
                        }
                        return
                    }
                    self.logEvent("will update results")
                    results.numberOfSteps = data.numberOfSteps.intValue
                    results.distanceCovered = data.distance?.doubleValue ?? 0
                    self.logEvent("will resume continuation")
                    continuation.resume()
                }
            }
            self.logEvent("will return results (\(results))")
            try? await standard.uploadHealthObservation(results)
            return results
        }
    }
}


extension TimedWalkingTest {
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

extension TimedWalkingTest {
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
