//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

#if os(iOS)

public import ActivityKit
public import Foundation
public import SpeziStudyDefinition


public struct TimedWalkTestLiveActivityAttributes: ActivityAttributes {
    public enum ContentState: Hashable, Codable, Sendable {
        case ongoing(startDate: Date)
        case completed(numSteps: Int, distance: Measurement<UnitLength>)
    }
    
    public let test: TimedWalkingTestConfiguration
    
    public init(test: TimedWalkingTestConfiguration) {
        self.test = test
    }
}

#endif
