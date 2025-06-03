//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import MyHeartCountsShared
import Spezi
import SpeziHealthKit
import WatchKit


@Observable
@MainActor
final class WorkoutManager: NSObject, Module, EnvironmentAccessible, HKWorkoutSessionDelegate {
    private enum WorkoutSessionError: Error {
        case alreadyAWorkoutOngoing
    }
    
    enum State: Hashable, Sendable {
        case idle
        case active(startDate: Date)
    }
    
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    // swiftlint:enable attributes
    
    private var workoutSession: HKWorkoutSession?
    
    private(set) var state: State = .idle
    
    
    private func updateState() {
        guard let workoutSession else {
            state = .idle
            return
        }
        switch workoutSession.state {
        case .notStarted, .prepared:
            state = .idle
        case .running, .paused:
            if let startDate = workoutSession.startDate {
                state = .active(startDate: startDate)
            }
        case .ended:
            state = .idle
        case .stopped:
            state = .idle
        @unknown default:
            if let startDate = workoutSession.startDate {
                state = .active(startDate: startDate)
            } else {
                state = .idle
            }
        }
    }
    
    
    func startWorkout(for activityType: TimedWalkingTestConfiguration.Kind) async throws {
        guard workoutSession == nil else {
            throw WorkoutSessionError.alreadyAWorkoutOngoing
        }
        try await healthKit.askForAuthorization()
        let configuration = HKWorkoutConfiguration()
        switch activityType {
        case .walking:
            configuration.activityType = .walking
        case .running:
            configuration.activityType = .running
        }
        // does this matter? do we want to somehow ask the user / try to figure it out?
        // the iPhone (and probably also the watch) do know whether they're indoors/outdoors, so we might be able to access that information?
        // maybe setting it to unknown results in the system doing this for us?
        configuration.locationType = .unknown
        
        let workoutSession = try HKWorkoutSession(
            healthStore: healthKit.healthStore,
            configuration: configuration
        )
        workoutSession.delegate = self
        self.workoutSession = workoutSession
        
        let builder = workoutSession.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthKit.healthStore, workoutConfiguration: configuration)
//        builder.delegate = self // ?? (do we care?)
        
        workoutSession.startActivity(with: .now)
        try await builder.beginCollection(at: .now)
    }
    
    
    func stopWorkout() async throws {
        guard let workoutSession else {
            return
        }
        let builder = workoutSession.associatedWorkoutBuilder()
        try await builder.endCollection(at: .now)
        try await builder.finishWorkout()
        workoutSession.stopActivity(with: .now)
        // NOTE: we're intentionally not setting self.workoutSession to nil in here, but instead do it in the delegate below.
    }
    
    
    // MARK: HKWorkoutSessionDelegate
    
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            if toState == .stopped {
                self.workoutSession = nil
            }
            updateState()
        }
        if (fromState != .running && toState == .running) || (fromState == .running && (toState == .stopped || toState == .ended)) {
            WKInterfaceDevice.current().play(.success)
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            updateState()
            self.workoutSession = nil
        }
    }
}


extension HKWorkoutSessionState {
    var displayTitle: String {
        switch self {
        case .notStarted:
            "not started"
        case .running:
            "running"
        case .ended:
            "ended"
        case .paused:
            "paused"
        case .prepared:
            "prepared"
        case .stopped:
            "stopped"
        @unknown default:
            "unknown<\(rawValue)>"
        }
    }
}
