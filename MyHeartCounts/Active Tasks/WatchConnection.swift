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
    @Dependency(HealthKit.self) private var healthKit
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
        try await Task.sleep(for: .seconds(1.5)) // give it some time to boot up
        print("will send message (start workout)")
        let response = try await wcSession.sendMessage(
            try JSONEncoder().encode(RemoteCommand.startWorkoutOnWatch(kind: activityKind))
        )
        print("got response (to startWorkout msg)", response)
    }
    
    func stopWorkoutOnWatch() async throws {
        print("will send message (start workout)")
        let response = try await wcSession.sendMessage(
            try JSONEncoder().encode(RemoteCommand.endWorkoutOnWatch)
        )
        print("got response (to endWorkout msg)", response)
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


//extension WatchConnection {
//    private class SessionDelegate: NSObject, WCSessionDelegate {
//        unowned let watchConnection: WatchConnection
//        
//        nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
//            // ...
//        }
//    }
//}
