//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import Charts
import Foundation
import HealthKit
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


private struct SleepSession: Hashable, Identifiable {
    typealias SleepPhase = HKCategoryValueSleepAnalysis
    
    let id: Set<UUID>
    let samples: [HKCategorySample]
    let totalTrackedTime: TimeInterval
    let timeBySleepPhase: [SleepPhase: TimeInterval]
    
    init(_ samples: some Collection<HKCategorySample>) {
        self.id = samples.mapIntoSet(\.id)
        self.samples = Array(samples)
        timeBySleepPhase = samples.reduce(into: [:]) { result, sample in
            guard let phase = SleepPhase(rawValue: sample.value) else {
                return
            }
            result[phase, default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
        }
        totalTrackedTime = timeBySleepPhase.reduce(0) { $0 + $1.value }
    }
}


struct SleepPhasesCharts: View {
    @HealthKitQuery(.sleepAnalysis, timeRange: .last(weeks: 35))
    private var sleepStats
    
//    @Environment(\.colorScheme)
//    private var colorScheme
    
    @SleepPhaseColors private var sleepPhaseColors
    
    var body: some View {
        let sleepSessions = sleepStats
            .chunked(by: { $1.startDate.timeIntervalSince($0.endDate) < 1800 })
            .map { SleepSession($0) }
        Chart(sleepSessions) { (session: SleepSession) in
            let xVal: PlottableValue = .value("Date", session.samples.first!.startDate) // swiftlint:disable:this force_unwrapping
            let phases = SleepSession.SleepPhase.allPhases.filter { ![SleepSession.SleepPhase.inBed, .asleepUnspecified].contains($0) }
            ForEach(phases, id: \.self) { phase in
                if let timeInPhase = session.timeBySleepPhase[phase] {
                    let percentageInPhase = timeInPhase / session.totalTrackedTime // percentage of total or percentage of asleep?
                    LineMark(
                        x: xVal,
                        y: .value("Percentage in Phase", percentageInPhase),
                        series: .value("Sleep Phase", phase.displayTitle)
                    )
                    .foregroundStyle(by: .value("Sleep Phase", phase.displayTitle))
                }
            }
        }
        .chartForegroundStyleScale({ () -> KeyValuePairs<String, Color> in
            var mapping: [(String, Color)] = []
            for phase in SleepSession.SleepPhase.allPhases {
                mapping.append((phase.displayTitle, sleepPhaseColors[phase]))
            }
            return KeyValuePairs<String, Color>(mapping)
        }())
    }
}

extension SleepSession.SleepPhase {
    static let allPhases: [Self] = [
        .awake, .inBed, .asleepREM, .asleepCore, .asleepDeep, .asleepUnspecified
    ]
    var displayTitle: String {
        switch self {
        case .asleepCore:
            "Core Sleep"
        case .asleepDeep:
            "Deep Sleep"
        case .asleepREM:
            "REM Sleep"
        case .asleepUnspecified:
            "Asleep"
        case .awake:
            "Awake"
        case .inBed:
            "In Bed"
        @unknown default:
            "unknown"
        }
    }
}
