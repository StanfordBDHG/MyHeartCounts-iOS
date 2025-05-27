//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension PartialRangeFrom: @retroactive Equatable where Bound: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lowerBound == rhs.lowerBound
    }
}
extension PartialRangeFrom: @retroactive Hashable where Bound: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(lowerBound)
    }
}

extension PartialRangeUpTo: @retroactive Equatable where Bound: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.upperBound == rhs.upperBound
    }
}
extension PartialRangeUpTo: @retroactive Hashable where Bound: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(upperBound)
    }
}

extension PartialRangeThrough: @retroactive Equatable where Bound: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.upperBound == rhs.upperBound
    }
}
extension PartialRangeThrough: @retroactive Hashable where Bound: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(upperBound)
    }
}
