//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
@_spi(APISupport)
import Spezi
import SpeziFoundation
import SpeziLocalStorage
import SpeziSensorKit
import SwiftUI


extension HomeTab {
    @MainActor
    @propertyWrapper
    struct PromptedActions: DynamicProperty {
        // swiftlint:disable attributes
        @Environment(\.calendar) private var cal
        @LocalPreference(.studyActivationDate) private var studyActivationDate
        @LocalPreference(.rejectedHomeTabPromptedActions) private var rejectedActionIds
        // swiftlint:enable attributes
        
        @MainActor var wrappedValue: [HomeTab.PromptedAction] {
            let daysSinceEnrollment = studyActivationDate.map { cal.offsetInDays(from: $0, to: .now) }
            return PromptedAction.allActions.filter { action in
                guard !rejectedActionIds.contains(action.id) else {
                    return false
                }
                return action.conditions.allSatisfy { condition in
                    switch condition {
                    case .daysSinceEnrollment(let range):
                        daysSinceEnrollment.map { range.contains($0) } ?? false
                    case .custom(let predicate):
                        SpeziAppDelegate.spezi.map(predicate) ?? false
                    }
                }
            }
        }
        
        var projectedValue: Self {
            self
        }
        
        func reject(_ actionId: PromptedAction.ID) {
            rejectedActionIds.insert(actionId)
        }
    }
}

extension LocalPreferenceKeys {
    static let rejectedHomeTabPromptedActions = LocalPreferenceKey<Set<HomeTab.PromptedAction.ID>>(
        "rejectedHomeTabPromptedActions",
        default: []
    )
}
