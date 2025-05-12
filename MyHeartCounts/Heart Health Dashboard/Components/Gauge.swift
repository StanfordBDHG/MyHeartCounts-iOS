//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


private struct GaugeRing: Shape {
    private(set) var progress: CGFloat
    
    
    var animatableData: CGFloat {
        get {
            progress
        }
        set {
            progress = newValue
        }
    }
    
    
    init(progress: CGFloat) {
        self.progress = progress
    }
    
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(
                center: CGPoint(x: rect.width / 2, y: rect.height / 2),
                radius: min(rect.width, rect.height) / 2,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: progress * 360.0),
                clockwise: false
            )
        }
    }
}

struct Gauge: View {
    let lineWidth: Double
    let shaddowRadius: Double
    let gradient: Gradient
    let backgroundColor: Color
    let progress: Double
    
    @State private var size: CGSize = .zero
    
    
    private var shaddowOffset: CGPoint {
        let angle = Angle(degrees: progress * 360.0).radians
        return CGPoint(x: cos(angle) * shaddowRadius * 2.0, y: sin(angle) * shaddowRadius * 2.0)
    }
    
    private var radius: Double {
        (size.height / 2) - (lineWidth / 2)
    }
    
    var body: some View {
        ZStack { // swiftlint:disable:this closure_body_length
            GeometryReader { proxy in
                Circle()
                    .stroke(backgroundColor, lineWidth: lineWidth)
                    .padding(lineWidth / 2)
                    .onAppear {
                        self.size = proxy.size
                    }
            }
            GaugeRing(progress: progress)
                .stroke(
                    AngularGradient(
                        gradient: gradient,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(progress * 360.0)
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(lineWidth / 2)
            if progress < 1.0 - (lineWidth / (2 * radius * .pi)) {
                Circle()
                    .frame(width: lineWidth)
                    .foregroundColor(gradient.stops.first?.color)
                    .offset(y: -(size.height / 2) + (lineWidth / 2))
            } else {
                let shaddowOffset = shaddowOffset
                Circle()
                    .frame(width: lineWidth)
                    .foregroundColor(gradient.stops.last?.color)
                    .offset(y: -(size.height / 2) + (lineWidth / 2))
                    .rotationEffect(Angle.degrees(360 * Double(progress)))
                    .shadow(
                        color: .black.opacity(0.2),
                        radius: shaddowRadius,
                        x: shaddowOffset.x,
                        y: shaddowOffset.y
                    )
            }
        }
            .aspectRatio(1.0, contentMode: .fit)
            .animation(.easeOut, value: progress)
    }
    
    
    init(
        progress: Double,
        gradient: Gradient,
        backgroundColor: Color,
        lineWidth: Double = 20,
        shaddowRadius: Double = 4
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.shaddowRadius = shaddowRadius
        self.gradient = gradient
        self.backgroundColor = backgroundColor
    }
    
    init(
        progress: Double,
        color: Color = .accentColor,
        lineWidth: Double = 20
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.shaddowRadius = lineWidth / 5
        self.gradient = Gradient(colors: [color, color])
        self.backgroundColor = color.opacity(0.2)
    }
}


#if DEBUG
#Preview {
    Gauge(progress: 0.981, color: .red)
        .padding()
}

#Preview("Animation") {
    struct PreviewWrapper: View {
        @State var progress = 0.0
        
        var body: some View {
            Gauge(progress: progress)
                .task {
                    while true {
                        progress += Double.random(in: 0.0...0.05)
                        try? await Task.sleep(for: .seconds(1))
                    }
                }
        }
    }
    
    return PreviewWrapper()
        .padding()
}
#endif
