//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

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
