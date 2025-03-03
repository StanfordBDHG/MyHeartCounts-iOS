//
//  Utils.swift
//  MyHeartCounts
//
//  Created by Lukas Kollmer on 2025-02-24.
//

import Foundation
import SFSafeSymbols
import SpeziViews
import SwiftUI


@propertyWrapper
struct NotNilAssignable<T> {
    private var value: T?
    
    var wrappedValue: T? {
        get { value }
        set {
            if let newValue {
                value = newValue
            } else {
                // if someone tries to assign nil, we keep the current value.
            }
        }
    }
    
    init() {
        value = nil
    }
    
    init(wrappedValue: T?) {
        value = wrappedValue
    }
}

extension NotNilAssignable: Sendable where T: Sendable {}


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
