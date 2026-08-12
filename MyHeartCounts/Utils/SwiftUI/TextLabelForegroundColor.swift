//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct TextLabelForegroundColor: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? .white : .black
    }
}


extension ShapeStyle where Self == TextLabelForegroundColor {
    static var textLabel: Self {
        TextLabelForegroundColor()
    }
}
