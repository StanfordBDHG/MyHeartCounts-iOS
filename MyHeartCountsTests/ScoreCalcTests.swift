//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
@testable import MyHeartCounts
import SwiftUI
import Testing


@Suite(.tags(.unitTest))
struct ScoreCalcTests {
    @Test
    func scoreCalcA() {
        let score = ScoreDefinition(default: 0, scoringBands: [
            .inRange(0..<5, score: 1),
            .inRange(5..<10, score: 2),
            .equal(to: 12, score: 12, explainerBand: .init(leadingText: "12", trailingText: "12", background: .color(.red)))
        ])
        #expect(score(0) == 1)
        #expect(score(-0) == 1)
        #expect(score(-1) == 0)
        #expect(score(4) == 1)
        #expect(score(5) == 2)
        #expect(score(9) == 2)
        #expect(score(10) == 0)
        #expect(score(12) == 12)
    }
    
    @Test
    func scoreCalcB() {
        let score = ScoreDefinition.cvhBloodPressure
        #expect(score(BloodPressureMeasurement(systolic: 110, diastolic: 75)) == 1)
    }
}
