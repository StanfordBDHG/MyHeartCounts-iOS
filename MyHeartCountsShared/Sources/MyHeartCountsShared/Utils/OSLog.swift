//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import OSLog


extension Logger {
    /// A Logging Category
    public struct Category: Sendable {
        @usableFromInline let value: String
        
        /// Creates a new Category
        @inlinable
        public init(_ value: String) {
            self.value = value
        }
    }
}

extension Logger.Category {
    // periphery:ignore - API
    /// The system-defined POI logging category
    public static let pointsOfInterest = Self("PointsOfInterest")
}


extension Logger {
    /// Creates a new Logger from a ``Category``.
    @inlinable
    public init(subsystem: String = "edu.stanford.MyHeartCounts", category: Category) {
        self.init(subsystem: subsystem, category: category.value)
    }
}
