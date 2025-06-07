//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A property wrapper that makes an `any Hashable` value hashable.
@propertyWrapper
struct MakeHashable: Hashable, Sendable {
    let wrappedValue: (any Hashable & Sendable)?
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.wrappedValue, rhs.wrappedValue) {
        case (.none, .none):
            type(of: lhs.wrappedValue) == type(of: rhs.wrappedValue)
        case (.none, .some), (.some, .none):
            false
        case let (.some(lhs), .some(rhs)):
            lhs.isEqual(rhs)
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch wrappedValue {
        case .none:
            hasher.combine(1)
        case .some(let value):
            hasher.combine(2)
            value.hash(into: &hasher)
        }
    }
}


extension Equatable {
    func isEqual(_ other: any Equatable) -> Bool {
        if let other = other as? Self {
            other == self
        } else {
            false
        }
    }
}


extension BinaryFloatingPoint {
    func isEqual(to other: some BinaryFloatingPoint) -> Bool {
        if let other = Self(exactly: other) {
            self.isEqual(to: other)
        } else {
            false
        }
    }
}
