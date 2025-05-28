//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


public struct TimedWalkingTest: Codable, Hashable, Sendable {
    public enum Kind: Codable, Hashable, CaseIterable, Sendable {
        case walking
        case running
    }
    
    public let duration: Duration
    public let kind: Kind
    
    public init(duration: Duration, kind: Kind) {
        self.duration = duration
        self.kind = kind
    }
}
