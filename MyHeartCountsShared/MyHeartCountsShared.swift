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
    case startWorkoutOnWatch(kind: TimedWalkingTest.Kind)
    case endWorkoutOnWatch
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
}

