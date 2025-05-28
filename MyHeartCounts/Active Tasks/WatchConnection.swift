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
import SpeziHealthKit
import WatchConnectivity


@MainActor
final class WatchConnection: NSObject, Module, WCSessionDelegate {
    @Dependency(HealthKit.self)
    private var healthKit
    
    nonisolated(unsafe) private let wcSession: WCSession = .default
    
    func configure() {
        wcSession.delegate = self
        wcSession.activate()
    }
    
    func startWorkoutOnWatch(for activityKind: TimedWalkingTest.Kind) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        try await healthKit.healthStore.startWatchApp(toHandle: configuration)
        try await Task.sleep(for: .seconds(4)) // give it some time to boot up
        let response = try await wcSession.sendMessage(
            try JSONEncoder().encode(RemoteCommand.startWorkoutOnWatch(kind: activityKind))
        )
    }
    
    func stopWorkoutOnWatch() async throws {
        let response = try await wcSession.sendMessage(
            try JSONEncoder().encode(RemoteCommand.endWorkoutOnWatch)
        )
    }
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        // ...
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // ...
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // ...
    }
}
