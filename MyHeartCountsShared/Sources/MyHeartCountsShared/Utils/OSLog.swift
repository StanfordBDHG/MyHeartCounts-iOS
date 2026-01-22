//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import OSLog


extension Logger {
    public struct Category: Sendable {
        @usableFromInline let value: String
        
        @inlinable
        public init(_ value: String) {
            self.value = value
        }
    }
}

extension Logger.Category {
    public static let pointsOfInterest = Self("PointsOfInterest")
}


extension Logger {
    @inlinable
    public init(subsystem: String = "edu.stanford.MyHeartCounts", category: Category) {
        self.init(subsystem: subsystem, category: category.value)
    }
}
