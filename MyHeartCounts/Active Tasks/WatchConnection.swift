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


/// A Module that runs on the iPhone and handles simple interactions with any connected Apple Watches.
@Observable
@MainActor
final class WatchConnection: NSObject, Module, EnvironmentAccessible, Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @Application(\.logger) private var logger
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    // swiftlint:enable attributes
    
    /// Indicates whether the user has an Apple Watch paired with their iPhone.
    ///
    /// - Note: This value being true does not necessarily mean that the Apple Watch is actually currently reachable and connected. (TODO IS THIS REALLY REALLY TRUE???)
    private(set) var userHasWatch = false
    /// Indicates whether the current app's counterpart Apple Watch app is currently reachable and can receive/send messages.
    private(set) var isWatchAppReachable = false
    /// Indicates whether the current app's counterpart Apple Watch app is currently installed.
    private(set) var isWatchAppInstalled = false
    
    nonisolated(unsafe) private let wcSession: WCSession = .default
    
    func configure() {
        wcSession.delegate = self
        wcSession.activate()
    }
    
    func launchWatchApp() async throws {
        let workoutConfig = HKWorkoutConfiguration()
        workoutConfig.activityType = .walking
        workoutConfig.locationType = .unknown
        try await healthKit.healthStore.startWatchApp(toHandle: workoutConfig)
    }
    
    func startWorkoutOnWatch(for activityKind: TimedWalkingTestConfiguration.Kind) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        try await healthKit.healthStore.startWatchApp(toHandle: configuration)
        try await Task.sleep(for: .seconds(4)) // give it some time to boot up
        wcSession.send(userInfo: [
            .watchShouldEnableWorkout: true,
            .watchWorkoutActivityKind: activityKind.rawValue
        ])
        let response = try await wcSession.sendMessage(
            try JSONEncoder().encode(RemoteCommand.startWorkoutOnWatch(kind: activityKind))
        )
    }
    
    func stopWorkoutOnWatch() async throws {
        wcSession.send(userInfo: [.watchShouldEnableWorkout: false])
        let response = try await wcSession.sendMessage(
            try JSONEncoder().encode(RemoteCommand.endWorkoutOnWatch)
        )
    }
}


extension WatchConnection: WCSessionDelegate {
    nonisolated private func updateStateRelatedProperties() {
        Task { @MainActor in
            let update = { (selfKeyPath: ReferenceWritableKeyPath<WatchConnection, Bool>, sessionKeyPath: KeyPath<WCSession, Bool>) in
                if self[keyPath: selfKeyPath] != self.wcSession[keyPath: sessionKeyPath] {
                    self[keyPath: selfKeyPath] = self.wcSession[keyPath: sessionKeyPath]
                }
            }
            update(\.userHasWatch, \.isPaired)
            update(\.isWatchAppInstalled, \.isWatchAppInstalled)
            update(\.isWatchAppReachable, \.isReachable)
        }
    }
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            self.logger.notice("-[\(Self.self) \(#function)] activationState: \(activationState.debugDescription); error: \(error)")
            updateStateRelatedProperties()
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // ...
        Task { @MainActor in
            self.logger.notice("-[\(Self.self) \(#function)]")
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // ...
        Task { @MainActor in
            self.logger.notice("-[\(Self.self) \(#function)]")
        }
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.logger.notice("-[\(Self.self) \(#function)]")
            updateStateRelatedProperties()
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.logger.notice("-[\(Self.self) \(#function)] (isReachable: \(self.wcSession.isReachable))")
            self.isWatchAppReachable = self.wcSession.isReachable
        }
    }
}


extension WCSessionActivationState: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .activated: "activated"
        case .notActivated: "notActivated"
        case .inactive: "inactive"
        @unknown default: "unknown<\(rawValue)>"
        }
    }
}
