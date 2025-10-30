//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


extension Binding {
    /// Creates a new `Binding` which maps `nil` values onto a non-nil value.
    func withDefault<Wrapped>(
        _ default: @autoclosure @Sendable @escaping () -> Wrapped
    ) -> Binding<Wrapped> where Value == Wrapped?, Self: Sendable {
        Binding<Wrapped> {
            self.wrappedValue ?? `default`()
        } set: {
            self.wrappedValue = $0
        }
    }
}
