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
import SpeziFoundation
import SpeziHealthKit
import SpeziStudyDefinition
import WatchConnectivity


/// A Module that runs on the iPhone and handles simple interactions with any connected Apple Watches.
@Observable
@MainActor
final class WatchConnection: NSObject, Module, EnvironmentAccessible, Sendable {
    enum LaunchWatchAppError: Error {
        case unableToFindWatch
    }
    
    // swiftlint:disable attributes
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    // swiftlint:enable attributes
    
    /// Indicates whether the user has an Apple Watch paired with their iPhone.
    ///
    /// - Note: This value being true might not necessarily mean that the Apple Watch is actually currently reachable and connected.
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
    
    func startWorkoutOnWatch(for test: TimedWalkingTestConfiguration) async throws {
        guard userHasWatch && isWatchAppInstalled && isWatchAppReachable else {
            throw LaunchWatchAppError.unableToFindWatch
        }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        try await healthKit.healthStore.startWatchApp(toHandle: configuration)
        wcSession.send(userInfo: [
            .watchShouldEnableWorkout: true,
            .watchWorkoutActivityKind: test.kind.rawValue,
            .watchWorkoutDuration: test.duration.timeInterval,
            .watchWorkoutStartDate: Date.now
        ])
    }
    
    func stopWorkoutOnWatch() async throws {
        wcSession.send(userInfo: [.watchShouldEnableWorkout: false])
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
            updateStateRelatedProperties()
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // ...
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // ...
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            updateStateRelatedProperties()
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchAppReachable = self.wcSession.isReachable
        }
    }
}
