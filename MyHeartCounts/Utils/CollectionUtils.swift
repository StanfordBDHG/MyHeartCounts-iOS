//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Collection {
    // periphery:ignore - API
    /// Returns the elements of the sequence, sorted using the given array of
    /// `SortComparator`s to compare elements.
    ///
    /// - Parameters:
    ///   - comparators: an array of comparators used to compare elements. The
    ///   first comparator specifies the primary comparator to be used in
    ///   sorting the sequence's elements. Any subsequent comparators are used
    ///   to further refine the order of elements with equal values.
    /// - Returns: an array of the elements sorted using `comparators`.
    @_disfavoredOverload
    public func sorted(using comparators: some Sequence<any SortComparator<Element>>) -> [Element] {
        var copy = Array(self)
        copy.sort(using: comparators)
        return copy
    }
}


extension MutableCollection where Self: RandomAccessCollection {
    /// Sorts the collection using the given array of `SortComparator`s to
    /// compare elements.
    ///
    /// - Parameters:
    ///   - comparators: an array of comparators used to compare elements. The
    ///   first comparator specifies the primary comparator to be used in
    ///   sorting the sequence's elements. Any subsequent comparators are used
    ///   to further refine the order of elements with equal values.
    @_disfavoredOverload
    public mutating func sort(using comparators: some Sequence<any SortComparator<Element>>) {
        guard let primaryComparator = comparators.first(where: { _ in true }) else {
            return
        }
        self.sort { lhs, rhs in
            switch primaryComparator.compare(lhs, rhs) {
            case ComparisonResult.orderedAscending:
                return true
            case ComparisonResult.orderedDescending:
                return false
            case ComparisonResult.orderedSame:
                for comparator in comparators.dropFirst() {
                    switch comparator.compare(lhs, rhs) {
                    case .orderedAscending:
                        return true
                    case .orderedDescending:
                        return false
                    case .orderedSame:
                        continue
                    }
                }
                return false
            }
        }
    }
}


extension RangeReplaceableCollection {
    mutating func removeFirst(where predicate: (Element) -> Bool) {
        if let idx = firstIndex(where: predicate) {
            remove(at: idx)
        }
    }
}
