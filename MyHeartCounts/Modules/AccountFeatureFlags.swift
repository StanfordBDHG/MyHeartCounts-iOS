//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziAccount


@Observable
@MainActor
final class AccountFeatureFlags: Module, EnvironmentAccessible, DefaultInitializable, Sendable {
    private(set) var isDebugModeEnabled = false
    
    nonisolated init() {}
    
    
    func _updateIsDebugModeEnabled(_ newValue: Bool) { // swiftlint:disable:this identifier_name
        isDebugModeEnabled = newValue
    }
}


extension AccountDetails {
    @AccountKey(id: "enableAppDebugMode", name: "Enable App Debug Mode", as: Bool.self)
    var enableDebugMode: Bool? // swiftlint:disable:this discouraged_optional_boolean
}


@KeyEntry(\.enableDebugMode)
extension AccountKeys {}
