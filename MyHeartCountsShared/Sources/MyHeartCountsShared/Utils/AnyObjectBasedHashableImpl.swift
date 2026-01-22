//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

/// provides identity-based default implementations for `Equatable` and `Hashable` conformances, for `AnyObject` types that conform to either or both of these protocols.
@_marker
public protocol AnyObjectBasedDefaultImpls {}

extension AnyObjectBasedDefaultImpls where Self: AnyObject & Equatable {
    /// Default `Equatable` implementation, using the object's identity.
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension AnyObjectBasedDefaultImpls where Self: AnyObject & Hashable {
    /// Default `Hashable` implementation, using the object's identity.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
