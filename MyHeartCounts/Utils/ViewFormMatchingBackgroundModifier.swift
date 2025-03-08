//
//  ViewFormMatchingBackgroundModifier.swift
//  MyHeartCounts
//
//  Created by Lukas Kollmer on 08.03.25.
//

import SwiftUI
import class UIKit.UIColor


private struct ViewFormMatchingBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        // It seems that this (using background vs backgroundStyle) depending on light/dark mode is what we need to do
        // in order to have the view background match the form background...
        // TODO(@lukas) why is this the case?
        if colorScheme == .dark {
            content.backgroundStyle(Color(uiColor: UIColor.secondarySystemBackground))
        } else {
            content.background(Color(uiColor: UIColor.secondarySystemBackground))
        }
    }
}


extension View {
    func makeBackgroundMatchFormBackground() -> some View {
        self.modifier(ViewFormMatchingBackgroundModifier())
    }
}
