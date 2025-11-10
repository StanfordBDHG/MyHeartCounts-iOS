//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog


extension Logger {
    struct Category: Sendable {
        fileprivate let value: String
        
        init(_ value: String) {
            self.value = value
        }
    }
}

extension Logger.Category {
    static let pointsOfInterest = Self("PointsOfInterest")
}


extension Logger {
    init(subsystem: String = "edu.stanford.MyHeartCounts", category: Category) {
        self.init(subsystem: subsystem, category: category.value)
    }
}
