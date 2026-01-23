//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


extension SetAlgebra {
    /// Whether the set has any elements in common with another set.
    @inlinable
    public func overlaps(_ other: Self) -> Bool {
        !isDisjoint(with: other)
    }
}
