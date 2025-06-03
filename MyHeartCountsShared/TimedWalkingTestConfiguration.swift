//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A Timed Walking Test's configuration
public struct TimedWalkingTestConfiguration: Codable, Hashable, Sendable {
    /// The kind of a Timed Walking Test
    public enum Kind: UInt8, Codable, Hashable, CaseIterable, Sendable {
        /// A test that observes the user walking
        case walking
        /// A test that observes the user running
        case running
    }
    
    /// How long the test should be conducted
    public let duration: Duration
    /// The kind of test
    public let kind: Kind
    
    /// Creates a new Timed Walking Test configuration
    public init(duration: Duration, kind: Kind) {
        self.duration = duration
        self.kind = kind
    }
}
