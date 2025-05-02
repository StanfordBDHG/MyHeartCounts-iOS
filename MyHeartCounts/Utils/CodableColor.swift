//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import struct SwiftUI.Color
import struct SwiftUI.EnvironmentValues


enum CodableColor: Codable, Hashable, Sendable {
    enum SystemColor: String, Codable, Hashable {
        case red
        case orange
        case yellow
        case green
        case mint
        case teal
        case cyan
        case blue
        case indigo
        case purple
        case pink
        case brown
        case white
        case gray
        case black
        case clear
        case primary
        case secondary
    }
    
    case systemColor(SystemColor)
    case resolved(Color.Resolved)
    
    init(_ color: Color, environment: EnvironmentValues = .init()) { // swiftlint:disable:this cyclomatic_complexity
        switch color {
        case .red:
            self = .systemColor(.red)
        case .orange:
            self = .systemColor(.orange)
        case .yellow:
            self = .systemColor(.yellow)
        case .green:
            self = .systemColor(.green)
        case .mint:
            self = .systemColor(.mint)
        case .teal:
            self = .systemColor(.teal)
        case .cyan:
            self = .systemColor(.cyan)
        case .blue:
            self = .systemColor(.blue)
        case .indigo:
            self = .systemColor(.indigo)
        case .purple:
            self = .systemColor(.purple)
        case .pink:
            self = .systemColor(.pink)
        case .brown:
            self = .systemColor(.brown)
        case .white:
            self = .systemColor(.white)
        case .gray:
            self = .systemColor(.gray)
        case .black:
            self = .systemColor(.black)
        case .clear:
            self = .systemColor(.clear)
        case .primary:
            self = .systemColor(.primary)
        case .secondary:
            self = .systemColor(.secondary)
        default:
            self = .resolved(color.resolve(in: environment))
        }
    }
}


extension Color {
    init(_ other: CodableColor) { // swiftlint:disable:this cyclomatic_complexity
        switch other {
        case .resolved(let resolved):
            self.init(resolved)
        case .systemColor(.red):
            self = .red
        case .systemColor(.orange):
            self = .orange
        case .systemColor(.yellow):
            self = .yellow
        case .systemColor(.green):
            self = .green
        case .systemColor(.mint):
            self = .mint
        case .systemColor(.teal):
            self = .teal
        case .systemColor(.cyan):
            self = .cyan
        case .systemColor(.blue):
            self = .blue
        case .systemColor(.indigo):
            self = .indigo
        case .systemColor(.purple):
            self = .purple
        case .systemColor(.pink):
            self = .pink
        case .systemColor(.brown):
            self = .brown
        case .systemColor(.white):
            self = .white
        case .systemColor(.gray):
            self = .gray
        case .systemColor(.black):
            self = .black
        case .systemColor(.clear):
            self = .clear
        case .systemColor(.primary):
            self = .primary
        case .systemColor(.secondary):
            self = .secondary
        }
    }
}
