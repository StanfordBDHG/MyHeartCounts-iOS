//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct ScoreResultGauge: View {
    private let scoreResult: ScoreResult
    private let lineWidth: Gauge.LineWidth
    private let gradient: Gradient
    
    var body: some View {
        Gauge(
            lineWidth: lineWidth,
            gradient: scoreResult.scoreAvailable ? gradient : Gradient(colors: [.secondary]),
            progress: scoreResult.score
        ) {
            if let score = scoreResult.score, !score.isNaN {
                Text(Int(score * 100), format: .number)
                    .font(.headline)
                    .accessibilityLabel("Score Result: \(Int(score * 100)) percent")
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    init(
        scoreResult: ScoreResult,
        lineWidth: Gauge.LineWidth = .relative(1.5)
    ) {
        self.lineWidth = lineWidth
        self.scoreResult = scoreResult
        let explainer = scoreResult.definition.variant.explainer
        if let band = explainer.bands.first, explainer.bands.count == 1, case .gradient(let gradient) = band.background {
            self.gradient = gradient
        } else {
            self.gradient = .redToGreen
        }
    }
}


#Preview {
    ScoreResultGauge(
        scoreResult: ScoreResult(
            "Blood Lipids",
            sampleType: .custom(.bloodLipids),
            definition: ScoreDefinition(default: 0, scoringBands: [])
        )
    )
}
