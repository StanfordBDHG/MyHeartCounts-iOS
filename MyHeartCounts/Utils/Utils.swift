//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import Foundation
import SFSafeSymbols
import SpeziViews


extension RangeReplaceableCollection {
    func appending(contentsOf other: some Sequence<Element>) -> Self {
        var copy = self
        copy.append(contentsOf: other)
        return copy
    }
}


extension ViewState {
    @_disfavoredOverload
    static func error(_ error: some Error) -> Self {
        Self.error(AnyLocalizedError(error: error))
    }
}


extension ImageReference {
    static func system(_ symbol: SFSymbol) -> Self {
        .system(symbol.rawValue)
    }
}


extension URL: @retroactive ExpressibleByStringLiteral, @retroactive ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        if let url = URL(string: value) {
            self = url
        } else {
            fatalError("Unable to create URL from string '\(value)'")
        }
    }
}


extension StringProtocol {
    /// Returns a Substring with the receiver's leading and trailing whitespace removed
    public func trimmingLeadingAndTrailingWhitespace() -> SubSequence {
        trimmingLeadingWhitespace().trimmingTrailingWhitespace()
    }
    
    /// Returns a Substring with the receiver's leading whitespace removed
    public func trimmingLeadingWhitespace() -> SubSequence {
        drop(while: \.isWhitespace)
    }
    
    /// Returns a Substring with the receiver's trailing whitespace removed
    public func trimmingTrailingWhitespace() -> SubSequence {
        if let last = self.last, last.isWhitespace {
            dropLast().trimmingTrailingWhitespace()
        } else {
            self[...]
        }
    }
}


extension Sequence {
    func min<T: Comparable>(by keyPath: KeyPath<Element, T>) -> Element? {
        self.min { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }
    
    func max<T: Comparable>(by keyPath: KeyPath<Element, T>) -> Element? {
        self.max { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }
    
    func min<T: Comparable>(of keyPath: KeyPath<Element, T>) -> T? {
        self.min { $0[keyPath: keyPath] < $1[keyPath: keyPath] }?[keyPath: keyPath]
    }
    
    func max<T: Comparable>(of keyPath: KeyPath<Element, T>) -> T? {
        self.max { $0[keyPath: keyPath] < $1[keyPath: keyPath] }?[keyPath: keyPath]
    }
    
    func minAndMax<T: Comparable>(of keyPath: KeyPath<Element, T>) -> (min: T, max: T)? {
        var iterator = self.makeIterator()
        guard let first = iterator.next() else {
            return nil
        }
        var min = first[keyPath: keyPath]
        var max = min
        while let next = iterator.next() {
            let val = next[keyPath: keyPath]
            min = Swift.min(min, val)
            max = Swift.max(max, val)
        }
        return (min, max)
    }
}


extension Sequence {
    /// Returns a new sequence that chains the `other` sequence onto the end of the sequence.
    func chaining<Other: Sequence<Element>>(before other: Other) -> Chain2Sequence<Self, Other> {
        chain(self, other)
    }
    
    /// Returns a new sequence that chains the sequence onto the end of the `other` sequence.
    func chaining<Other: Sequence<Element>>(after other: Other) -> Chain2Sequence<Other, Self> {
        chain(other, self)
    }
}


extension Collection where Index == Int {
    func elements(at indices: IndexSet) -> [Element] {
        indices.map { self[$0] }
    }
}


extension Int {
    @inlinable
    init(_ decimal: Decimal) {
        self = NSDecimalNumber(decimal: decimal).intValue // swiftlint:disable:this legacy_objc_type
    }
}

extension Double {
    @inlinable
    init(_ decimal: Decimal) {
        self = NSDecimalNumber(decimal: decimal).doubleValue // swiftlint:disable:this legacy_objc_type
    }
}


extension Result {
    var value: Success? {
        switch self {
        case .success(let value):
            value
        case .failure:
            nil
        }
    }
}


extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    var appBuildNumber: Int? {
        (infoDictionary?["CFBundleVersion"] as? String).flatMap(Int.init)
    }
}


extension OptionSet {
    mutating func toggleMembership(of member: Element) {
        if contains(member) {
            remove(member)
        } else {
            insert(member)
        }
    }
}


extension Sequence {
    func map<Result, E>(_ transform: (Element) async throws(E) -> Result) async throws(E) -> [Result] {
        var results: [Result] = []
        results.reserveCapacity(underestimatedCount)
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
    
    
    func average() -> Element? where Element: BinaryFloatingPoint {
        var iterator = self.makeIterator()
        guard let first = iterator.next() else {
            return nil
        }
        var count = 1
        var avg: Element = first
        while let element = iterator.next() {
            count += 1
            avg += element
        }
        return avg / Element(count)
    }
}
