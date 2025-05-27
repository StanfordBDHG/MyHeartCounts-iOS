//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct CircularProgressView: View {
    private let value: Double
    private let lineWidth: Double
    private let showProgressAsLabel: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    .tint.opacity(0.5),
                    lineWidth: lineWidth
                )
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    .tint,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: value)
            if showProgressAsLabel {
                Text(String(format: "%.0f%%", value * 100))
                    .monospacedDigit()
            }
        }
        .padding(EdgeInsets(horizontal: lineWidth / 2, vertical: lineWidth / 2))
    }
    
    init(_ value: some BinaryFloatingPoint, lineWidth: Double = 5, showProgressAsLabel: Bool = false) {
        self.value = Double(value)
        self.lineWidth = lineWidth
        self.showProgressAsLabel = showProgressAsLabel
    }
}
