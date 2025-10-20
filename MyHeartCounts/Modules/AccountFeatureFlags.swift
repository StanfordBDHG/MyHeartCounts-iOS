//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order attributes

import Foundation
import Spezi
import SpeziAccount
import SwiftUI


@Observable
@MainActor
final class AccountFeatureFlags: Module, EnvironmentAccessible, DefaultInitializable, Sendable {
    private(set) var isDebugModeEnabled = false
    
    nonisolated init() {}
    
    func _updateIsDebugModeEnabled(_ newValue: Bool) { // swiftlint:disable:this identifier_name
        isDebugModeEnabled = newValue
    }
}


@MainActor
@propertyWrapper
struct DebugModeEnabled: DynamicProperty {
    @Environment(AccountFeatureFlags.self) private var flags
    
    var wrappedValue: Bool {
        flags.isDebugModeEnabled
    }
}
