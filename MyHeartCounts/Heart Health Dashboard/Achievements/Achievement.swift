//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import class HealthKit.HKUnit
import class HealthKit.HKQuantity

// swiftlint:disable all



struct Achievement: Hashable, Codable, Sendable {
    enum Goal: Hashable, Codable, Sendable {
        enum ReachLevelTarget: Hashable, Codable, Sendable {
            case absolute(Double)
            case newMaximum
        }
        case reachLevel(ReachLevelTarget)
        case maintainLevel
    }
    
    let title: String
    let goal: Goal
    
    init(title: String, goal: Goal) { // TODO add an LocalizedStringResource overload!
        self.title = title
        self.goal = goal
    }
}




extension Achievement {
    enum ResolvedGoal: Hashable, Sendable {
        /// The goal is achieved by reaching (or surpassing) a specified quantity.
        /// - parameter quantity: The target quantity
        /// - parameter invert: Whether the goal should be inverted;
        ///     i.e., whether it should be considered achieved if an actual value is below, rather than above, the quantity.
        case reachOrSurpass(_ quantity: HKQuantity, invert: Bool = false)
        
        @available(*, deprecated, message: "don't use this!!!")
        var quantity: HKQuantity {
            switch self {
            case .reachOrSurpass(let quantity, invert: _):
                quantity
            }
        }
        
        /// Evaluates a concrete value against the goal's value.
        ///
        /// - returns: A `Double` value, indicating how close the `measuredValue` is to the goal's value
        func evaluate(_ measuredQuantity: HKQuantity, unit: HKUnit) -> Double {
            switch self {
            case let .reachOrSurpass(targetQuantity, invert):
                let measuredValue = measuredQuantity.doubleValue(for: unit)
                let targetValue = targetQuantity.doubleValue(for: unit)
                if !invert {
                    return measuredValue / targetValue
                } else {
                    fatalError() // TODO
                }
            }
            fatalError()
        }
    }
}



struct AchievementStatus { // TODO better name!!!!!!!!
    
}
