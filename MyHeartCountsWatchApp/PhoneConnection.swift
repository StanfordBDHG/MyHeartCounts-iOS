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
import WatchConnectivity


@MainActor
final class PhoneConnection: NSObject, Module, WCSessionDelegate {
    // swiftlint:disable attributes
    @Application(\.logger) private var logger
    @Dependency(WorkoutManager.self) private var workoutManager
    // swiftlint:enable attributes
    
    private let wcSession: WCSession = .default
    
    func configure() {
        wcSession.delegate = self
        wcSession.activate()
    }
    
    
    /// - returns: `true` if the command was successfully executed; `false` otherwise
    private func handleCommand(_ command: RemoteCommand) async -> Bool {
        switch command {
        case .startWorkoutOnWatch(let activityType):
            do {
                try await workoutManager.startWorkout(for: activityType)
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
    
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        guard let command = try? JSONDecoder().decode(RemoteCommand.self, from: messageData) else {
            replyHandler(Data())
            return
        }
        nonisolated(unsafe) let replyHandler = replyHandler
        Task { @MainActor in
            let success = await self.handleCommand(command)
            replyHandler(Data([success ? 1 : 0]))
        }
    }
}
