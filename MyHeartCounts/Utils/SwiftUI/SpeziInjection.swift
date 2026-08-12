//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI


struct SpeziInjectionModifier: ViewModifier {
    @Environment(MyHeartCountsDelegate.self)
    private var appDelegate
    
    func body(content: Content) -> some View {
        content
            .spezi(appDelegate)
    }
}


extension View {
    /// Injects the default `Spezi` instance into the view hierarchy.
    func injectingSpezi() -> some View {
        self.modifier(SpeziInjectionModifier())
    }
}
