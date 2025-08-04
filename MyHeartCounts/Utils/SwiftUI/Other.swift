//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import CoreGraphics
import Foundation
import SFSafeSymbols
import SwiftUI


extension View {
    consuming func intoAnyView() -> AnyView {
        AnyView(self)
    }
    
    consuming func transforming(@ViewBuilder _ transform: (Self) -> some View) -> some View {
        transform(self)
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

extension SwiftUI.Label where Icon == Image {
    init(symbol: SFSymbol, @ViewBuilder title: () -> Title) {
        self.init(title: title) {
            Image(systemSymbol: symbol)
        }
    }
}


extension EdgeInsets {
    static var zero: EdgeInsets {
        Self(top: 0, leading: 0, bottom: 0, trailing: 0)
    }
    
    init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
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
