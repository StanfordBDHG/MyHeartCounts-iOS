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
