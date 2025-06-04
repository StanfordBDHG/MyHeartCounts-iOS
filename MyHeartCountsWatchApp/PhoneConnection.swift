//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MyHeartCountsShared
import Spezi
import SpeziStudyDefinition
import WatchConnectivity


/// A Module that runs on the Watch and handles simple interactions with its corresponding iPhone.
@Observable
@MainActor
final class PhoneConnection: NSObject, Module, WCSessionDelegate {
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(WorkoutManager.self) private var workoutManager
    // swiftlint:enable attributes
    
    @ObservationIgnored private let wcSession: WCSession = .default
    private(set) var userInfo: [InterDeviceUserInfoKey: Any] = [:]
    
    func configure() {
        wcSession.delegate = self
        wcSession.activate()
    }
    
    
    /// - returns: `true` if the command was successfully executed; `false` otherwise
    private func handleCommand(_ command: RemoteCommand) async -> Bool {
        switch command {
        case .startWorkoutOnWatch(let activityTypeRawValue):
            guard let kind = TimedWalkingTestConfiguration.Kind(rawValue: activityTypeRawValue) else {
                logger.error("Invalid kind rawValue (\(activityTypeRawValue))")
                return false
            }
            do {
                try await workoutManager.startWorkout(for: kind)
                return true
            } catch {
                logger.error("Error starting workout: \(error)")
                return false
            }
        case .endWorkoutOnWatch:
            do {
                try await workoutManager.stopWorkout()
                return true
            } catch {
                logger.error("Error stopping workout: \(error)")
                return false
            }
        }
    }
    
    // MARK: WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        // ...
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let userInfo: [InterDeviceUserInfoKey: Any] = .init(userInfo) else {
            return
        }
        let command: RemoteCommand
        if userInfo[.watchShouldEnableWorkout] as? Bool == true,
           let kindRawValue = userInfo[.watchWorkoutActivityKind] as? TimedWalkingTestConfiguration.Kind.RawValue,
           let kind = TimedWalkingTestConfiguration.Kind(rawValue: kindRawValue) {
            command = .startWorkoutOnWatch(kindRawValue: kind.rawValue)
        } else {
            command = .endWorkoutOnWatch
        }
        Task {
            await handleCommand(command)
        }
    }
}
