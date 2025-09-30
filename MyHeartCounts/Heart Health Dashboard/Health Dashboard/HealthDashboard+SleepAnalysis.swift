//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Charts
import Foundation
import HealthKit
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


struct SmallSleepAnalysisGridCell: View {
    @HealthKitQuery(.sleepAnalysis, timeRange: .last(days: 4), source: .appleHealthSystem)
    private var sleepAnalysis
    
    var body: some View {
        let sleepSessions = (try? sleepAnalysis.splitIntoSleepSessions()) ?? []
        
        HealthDashboardSmallGridCell(title: $sleepAnalysis.sampleType.mhcDisplayTitle) {
            EmptyView() // ?
        } content: {
            if let session = sleepSessions.last {
                let value = session.totalTimeSpentAsleep / 60 / 60
                HealthDashboardQuantityLabel(input: .init(
                    value: value,
                    valueString: String(format: "%.1f", value), // have "Xhrs Ymin" instead?
                    unit: .hour(),
                    timeRange: session.timeRange
                ))
            }
        }
    }
}


struct LargeSleepAnalysisView: View {
    private struct SleepData {
        let sessions: [SleepSession]
        /// key: noon
        /// value: total "asleep" duration of all sleep sessions that have their end in the `key` day.
        let timeAsleepByDay: [Date: TimeInterval]
    }
    
    @Environment(\.calendar)
    private var cal
    @Environment(\.showTimeRangeAsGridCellSubtitle)
    private var showTimeRangeAsSubtitle
    
    private let timeRange: HealthKitQueryTimeRange
    @HealthKitQuery<HKCategorySample> private var sleepAnalysis: Slice<OrderedArray<HKCategorySample>>
    @SleepPhaseColors private var sleepPhaseColors
    
    @State private var sleepData: Result<SleepData, any Error>?
    @State private var xSelection: Date?
    
    var body: some View {
        HealthDashboardSmallGridCell(
            title: SampleType.sleepAnalysis.mhcDisplayTitle,
            subtitle: showTimeRangeAsSubtitle ? timeRange.range.displayText(using: cal) : nil
        ) {
            cellContent
        }
    }
    
    @ViewBuilder private var cellContent: some View {
        Chart {
            switch sleepData {
            case nil, .failure:
                EmptyChartContent()
            case .success(let data):
                if !data.sessions.isEmpty {
                    chartContent(for: data)
                } else {
                    // ???
                }
            }
        }
        .chartOverlay { _ in
            switch sleepData {
            case nil:
                ProgressView("Processing Sleep Data…")
            case .success:
                EmptyView()
            case .failure:
                Text("Failed to process Sleep Sessions")
            }
        }
        .chartXScale(domain: [
            cal.startOfDay(for: timeRange.range.lowerBound),
            cal.startOfNextDay(for: timeRange.range.upperBound).addingTimeInterval(-1)
        ])
        .configureChartXAxisWithDailyMarks(forTimeRange: timeRange.range)
        .chartXSelection(value: $xSelection)
        // we need to place this modifier within the grid cell, rather than directly on the
        // HealthDashboardSmallGridCell, for reasons (https://github.com/swiftlang/swift/issues/84587)
        .onChange(of: Array(sleepAnalysis)) { _, samples in
            // the sleep session computation isn't exactly super slow,
            // but it might take a little bit (~0.1 sec),
            // so we want it to happen off the main thread.
            Task(priority: .userInitiated) {
                do {
                    let sessions = try await Task { @concurrent in
                        try samples.splitIntoSleepSessions()
                    }.value
                    sleepData = .success(.init(
                        sessions: sessions,
                        timeAsleepByDay: sessions.reduce(into: [:], { acc, session in
                            acc[cal.makeNoon(session.endDate), default: 0] += session.totalTimeSpentAsleep
                        })
                    ))
                } catch {
                    sleepData = .failure(error)
                }
            }
        }
        .onChange(of: $sleepAnalysis.isCurrentlyPerformingInitialFetch) { oldValue, newValue in
            if oldValue && !newValue && sleepAnalysis.isEmpty {
                sleepData = .success(.init(sessions: [], timeAsleepByDay: [:]))
            }
        }
    }
    
    init(timeRange: HealthKitQueryTimeRange) {
        self.timeRange = timeRange
        self._sleepAnalysis = .init(.sleepAnalysis, timeRange: timeRange, source: .appleHealthSystem)
    }
    
    /// - precondition: `sleepSessions` may not be empty.
    @ChartContentBuilder
    private func chartContent(for sleepData: SleepData) -> some ChartContent {
        ForEach(sleepData.sessions, id: \.self) { session in
            BarMark(
                x: .value("Date", cal.makeNoon(session.endDate)),
                y: .value("Time Asleep", session.totalTimeSpentAsleep / TimeConstants.hour),
                width: .automatic
            )
            .foregroundStyle(Color.blue)
        }
        if let xSelection,
           case let timeAsleepInDay = sleepData.timeAsleepByDay[cal.makeNoon(xSelection)] ?? 0 {
            ChartHighlightRuleMark(
                x: .value("Selected", xSelection, unit: .day, calendar: cal),
                primaryText: formatDuration(timeAsleepInDay),
                secondaryText: xSelection.formatted(.dateTime.calendar(cal).omittingTime())
            )
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / TimeConstants.hour)
        let minutes = Int(duration.truncatingRemainder(dividingBy: TimeConstants.hour) / TimeConstants.minute)
        return "\(hours) hr \(minutes) min"
    }
}


extension HKObject {
    var timeZone: TimeZone? {
        if let name = metadata?[HKMetadataKeyTimeZone] as? String {
            TimeZone(identifier: name)
        } else {
            nil
        }
    }
}


extension SleepSession.SleepPhase {
    var isAsleep: Bool {
        Self.allAsleepValues.contains(self)
    }
}


extension Range where Bound: Strideable, Bound.Stride: FloatingPoint {
    var middle: Bound {
        guard !isEmpty else {
            return lowerBound
        }
        let distance: Bound.Stride = lowerBound.distance(to: upperBound)
        let halfDistance: Bound.Stride = distance / 2
        return lowerBound.advanced(by: halfDistance)
    }
}
