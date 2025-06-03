//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import WatchConnectivity


public enum RemoteCommand: Hashable, Codable, Sendable {
    case startWorkoutOnWatch(kind: TimedWalkingTestConfiguration.Kind)
    case endWorkoutOnWatch
}


public struct InterDeviceUserInfoKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension InterDeviceUserInfoKey {
    public static let watchShouldEnableWorkout = Self(rawValue: "edu.stanford.MyHeartCounts.enableWatchWorkout")
    public static let watchWorkoutActivityKind = Self(rawValue: "edu.stanford.MyHeartCounts.watchWorkoutActivityKind")
}


extension WCSession {
    /// Sends a message and waits for a response.
    public func sendMessage(_ data: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.sendMessageData(data) { response in
                continuation.resume(returning: response)
            } errorHandler: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    public func send(userInfo: [InterDeviceUserInfoKey: Any]) {
        let userInfo: [String: Any] = .init(userInfo)
        self.transferUserInfo(userInfo)
    }
}
