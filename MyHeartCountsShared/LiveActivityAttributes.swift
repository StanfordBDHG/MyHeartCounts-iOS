//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

#if os(iOS)

import ActivityKit
import Foundation


public struct TimedWalkTestLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Hashable, Codable, Sendable {
        // TODO maybe use this to tell the widget when the test ended?
        public init() {}
    }
    
    public let encodedTest: Data
    public let startDate: Date
    
    public init(encodedTest: Data, startDate: Date) {
        self.encodedTest = encodedTest
        self.startDate = startDate
    }
}

#endif
