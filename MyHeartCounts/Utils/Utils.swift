//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Algorithms
import Foundation
import SFSafeSymbols
import SpeziViews
import SwiftUI


struct LazyView<Body: View>: View {
    private let makeBody: @MainActor () -> Body
    
    var body: Body {
        makeBody()
    }
    
    init(@ViewBuilder makeBody: @MainActor @escaping () -> Body) {
        self.makeBody = makeBody
    }
}


extension RangeReplaceableCollection {
    func appending(_ element: Element) -> Self {
        var copy = self
        copy.append(element)
        return copy
    }
    
    func appending(contentsOf other: some Sequence<Element>) -> Self {
        var copy = self
        copy.append(contentsOf: other)
        return copy
    }
}


extension ImageReference {
    static func systemSymbol(_ symbol: SFSymbol) -> Self {
        .system(symbol.rawValue)
    }
}


extension ViewState {
    @_disfavoredOverload
    static func error(_ error: some Error) -> Self {
        Self.error(AnyLocalizedError(error: error))
    }
}


/// marks a code path as being unreachable.
///
/// - Important: only use this in cases where you can prove that the path is actually unreachable; otherwise, this will introduce UB.
@_transparent
func unsafeUnreachable() -> Never {
    unsafeBitCast((), to: Never.self)
}


extension View {
    consuming func intoAnyView() -> AnyView {
        AnyView(self)
    }
    
    consuming func transforming(@ViewBuilder _ transform: (Self) -> some View) -> some View {
        transform(self)
    }
}

extension EdgeInsets {
    static let zero = Self(top: 0, leading: 0, bottom: 0, trailing: 0)
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


extension Collection {
    subscript(safe idx: Index) -> Element? {
        idx >= startIndex && idx < endIndex ? self[idx] : nil
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


extension EdgeInsets {
    init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}


extension Color {
    static func random() -> Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}


extension Angle {
    @inlinable
    func sin() -> Angle {
        .radians(_math.sin(radians))
    }
    
    @inlinable
    func cos() -> Angle {
        .radians(_math.cos(radians))
    }
}


extension CGPoint {
    func move(towards dstPoint: CGPoint, by distance: CGFloat) -> CGPoint {
        let difference = CGVector(dx: dstPoint.x - x, dy: dstPoint.y - y)
        let curDistance = (pow(x - dstPoint.x, 2) + pow(y - dstPoint.y, 2)).squareRoot()
        let relDistance = distance / curDistance
        return CGPoint(
            x: x + difference.dx * relDistance,
            y: y + difference.dy * relDistance
        )
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


private struct IdentifiableAdaptor<Value, ID: Hashable>: Identifiable {
    let value: Value
    let keyPath: KeyPath<Value, ID>
    
    var id: ID {
        value[keyPath: keyPath]
    }
}

extension View {
    func sheet<Item, ID: Hashable>(
        item: Binding<Item?>,
        id: KeyPath<Item, ID>,
        onDismiss: (@MainActor () -> Void)? = nil,
        @ViewBuilder content: @MainActor @escaping (Item) -> some View
    ) -> some View {
        let binding = Binding<IdentifiableAdaptor<Item, ID>?> {
            if let item = item.wrappedValue {
                IdentifiableAdaptor(value: item, keyPath: id)
            } else {
                nil
            }
        } set: { newValue in
            if let newValue {
                item.wrappedValue = newValue.value
            } else {
                item.wrappedValue = nil
            }
        }
        return self.sheet(item: binding, onDismiss: onDismiss) { item in
            content(item.value)
        }
    }
}


extension Double {
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
