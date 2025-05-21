//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import SwiftUI


struct Gauge2: View {
    struct LineWidth {
        /// The default line width. Matches the `SwiftUI.Gauge`.
        static let `default` = Self(value: 5.523809523809524)
        
        fileprivate let value: Double
        
        /// Creates a `LineWidth` my multiplying a fraction onto the default line width.
        static func relative(_ multiplier: Double) -> Self {
            Self(value: Self.default.value * multiplier)
        }
        
        static func absolute(_ width: Double) -> Self {
            Self(value: width)
        }
    }
    
    private static let openSegment: Double = 0.2
    /// The gauge's current value, with `0` representing an "empty" gauge, and `1` representing a "full" gauge
    private let progress: Double?
    
    private let lineWidth: LineWidth
    private let gradient: Gradient
    
    /// A textual representation of the current value.
    ///
    /// The value being represented here is not necessarily the same as ``value``.
    /// For example, it could be the case that a gauge representing a "daily step count" metric will have its ``value`` scaled onto a `0...1` range representing
    /// the user's progress towards a predefined step count goal, but then uses the ``currentValueString`` to display the total number of steps taken so far today,
    /// or the percentage of the user's progress towards the goal.
    let currentValueText: Text?
    /// A textual representation of the gauge's minimum value.
    let minimumValueText: Text?
    /// A textual representation of the gauge's maximum value.
    let maximumValueText: Text?
    
    private var startAngle: Angle {
        .radians(2.617993877991494)
    }
    private var endAngle: Angle {
        .radians(6.806784082777886)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Arc(startAngle: startAngle, endAngle: endAngle)
                    .stroke(
                        AngularGradient(
                            gradient: gradient,
                            center: .center,
                            startAngle: startAngle,
                            endAngle: endAngle
                        ),
                        style: StrokeStyle(lineWidth: lineWidth.value, lineCap: .round)
                    )
                    .padding(lineWidth.value / 2)
                let strokeWidth = lineWidth.value * 0.39
                if let position = highlightPointPosition(in: geometry.frame(in: .local)) {
                    Arc(startAngle: .zero, endAngle: .degrees(360))
                        .stroke(style: StrokeStyle(lineWidth: strokeWidth))
                        .frame(width: lineWidth.value + strokeWidth, height: lineWidth.value + strokeWidth)
                        .position(position)
                        .blendMode(.destinationOut)
                }
                if let currentValueText {
                    currentValueText
                }
                if let minimumValueText {
                    minimumValueText
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                if let maximumValueText {
                    maximumValueText
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .compositingGroup()
        }
    }
    
    
    private init(
        lineWidth: LineWidth,
        gradient: Gradient,
        progress: Double?,
        currentValueText: Text?,
        minimumValueText: Text?,
        maximumValueText: Text?
    ) {
        self.lineWidth = lineWidth
        self.gradient = gradient
        self.progress = progress.map { min(1, max(0, $0)) }
        self.currentValueText = currentValueText
        self.minimumValueText = minimumValueText
        self.maximumValueText = maximumValueText
    }
    
    init(
        lineWidth: LineWidth = .default, // swiftlint:disable:this function_default_parameter_at_end
        gradient: Gradient,
        progress: Double?
    ) {
        self.init(
            lineWidth: lineWidth,
            gradient: gradient,
            progress: progress,
            currentValueText: nil,
            minimumValueText: nil,
            maximumValueText: nil
        )
    }
    
    init(
        lineWidth: LineWidth = .default, // swiftlint:disable:this function_default_parameter_at_end
        gradient: Gradient,
        progress: Double?,
        currentValueText: () -> Text,
        minimumValueText: () -> Text,
        maximumValueText: () -> Text
    ) {
        self.init(
            lineWidth: lineWidth,
            gradient: gradient,
            progress: progress,
            currentValueText: currentValueText(),
            minimumValueText: minimumValueText(),
            maximumValueText: maximumValueText()
        )
    }
    
    init(
        lineWidth: LineWidth = .default, // swiftlint:disable:this function_default_parameter_at_end
        gradient: Gradient,
        progress: Double?,
        currentValueText: () -> Text
    ) {
        self.init(
            lineWidth: lineWidth,
            gradient: gradient,
            progress: progress,
            currentValueText: currentValueText(),
            minimumValueText: nil,
            maximumValueText: nil
        )
    }
    
    private func radius(in rect: CGRect) -> Double {
        radius(in: rect.size)
    }
    
    private func radius(in rect: CGSize) -> Double {
        min(rect.width, rect.height) / 2
    }
    
    private func highlightPointPosition(in rect: CGRect) -> CGPoint? {
        guard let progress else {
            return nil
        }
        let radius = radius(in: rect)
        let angle = Angle(radians: startAngle.radians + progress * (endAngle.radians - startAngle.radians))
        return CGPoint(
            x: (radius * cos(angle.radians)) + radius,
            y: (radius * sin(angle.radians)) + radius
        )
        .move(towards: .init(x: rect.width / 2, y: rect.height / 2), by: lineWidth.value / 2)
    }
}


private struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(
                center: rect.center,
                radius: min(rect.width, rect.height) / 2,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
    }
}


extension CGRect {
    var center: CGPoint {
        CGPoint(x: width / 2, y: height / 2)
    }
}
