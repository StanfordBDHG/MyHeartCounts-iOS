//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Charts
import Foundation
import HealthKit
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftUI


struct SmallSleepAnalysisGridCell: View {
    @HealthKitQuery(.sleepAnalysis, timeRange: .last(days: 4))
    private var sleepAnalysis
    
    var body: some View {
        let sleepSessions = try! sleepAnalysis.splitIntoSleepSessions() // swiftlint:disable:this force_try
        
        HealthDashboardSmallGridCell(title: $sleepAnalysis.sampleType.displayTitle) {
            EmptyView() // TODO?
        } content: {
            if let session = sleepSessions.last {
                HealthDashboardQuantityLabel(input: .init(
                    valueString: String(format: "%.1f", session.totalTimeAsleep / 60 / 60),
                    unitString: HKUnit.hour().unitString,
                    timeRange: session.timeRange
                ))
            }
        }
    }
}


struct LargeSleepAnalysisView: View { // TODO better name!
    private enum SleepData {
        case sleepSessions([SleepSession])
        case processingFailed(any Error)
    }
    
    @Environment(\.calendar)
    private var cal
    private let timeRange: HealthKitQueryTimeRange
    @HealthKitQuery<HKCategorySample> private var sleepAnalysis: Slice<OrderedArray<HKCategorySample>>
    @SleepPhaseColors private var sleepPhaseColors
    
    @State private var xSelection: Date?
    
    var body: some View {
        let sleepData = processSleepSessions()
        VStack(alignment: .leading) {
            Text("Recent Sleep Data")
                .font(.headline)
            Text(timeRange.range.displayText(using: cal))
                .font(.subheadline)
            Chart {
                switch sleepData {
                case .sleepSessions(let sessions):
                    chartContent(for: sessions)
                case .processingFailed:
                    EmptyChartContent()
                }
            }
            .chartOverlay { _ in
                switch sleepData {
                case .sleepSessions:
                    EmptyView()
                case .processingFailed:
                    Text("Failed to process Sleep Sessions")
                }
            }
            .chartXScale(domain: [cal.startOfDay(for: timeRange.range.lowerBound), cal.startOfNextDay(for: timeRange.range.upperBound).addingTimeInterval(-1)])
            .configureChartXAxisWithDailyMarks(forTimeRange: timeRange.range)
//            .chartXAxis {
//                let daysStride: Int = { () -> Int in
//                    if timeRange.duration <= TimeConstants.week {
//                        1
//                    } else if timeRange.duration <= TimeConstants.month {
//                        7
//                    } else {
//                        14
//                    }
//                }()
//                AxisMarks(values: .stride(by: .day, count: daysStride)) { value in
//                    if let date = value.as(Date.self) {
//                        if let prevDate = cal.date(byAdding: .day, value: -daysStride, to: date) {
//                            let format: Date.FormatStyle = .dateTime.omittingTime()
//                                .year(cal.isDate(prevDate, equalTo: date, toGranularity: .year) ? .omitted : .defaultDigits)
//                                .month(cal.isDate(prevDate, equalTo: date, toGranularity: .month) ? .omitted : .defaultDigits)
//                            AxisValueLabel(format: format)
//                        } else {
//                            AxisValueLabel(format: .dateTime.omittingTime())
//                        }
//                    }
//                    AxisGridLine()
//                    AxisTick()
//                }
//            }
            .chartXSelection(value: $xSelection)
        }
//        switch sleepData {
//        case .sleepSessions(let sessions):
//            NavigationLink("Sessions") {
//                Form {
//                    ForEach(sessions, id: \.self) { (session: SleepSession) in
//                        Section(coveredTimeRangeText(for: session.timeRange)) {
//                            ForEach(session) { (sample: HKCategorySample) in
//                                LabeledContent(sample.sleepPhase!.displayTitle, value: { () -> String in
//                                    let range = sample.timeRange
//                                    let startFormat: Date.FormatStyle = .dateTime.year(.defaultDigits).month(.abbreviated).day(.defaultDigits).hour(.twoDigits(amPM: .narrow)).minute(.twoDigits).second(.omitted)
//                                    let timeOnly: Date.FormatStyle = .dateTime.year(.omitted).month(.omitted).day(.omitted).hour(.twoDigits(amPM: .narrow)).minute(.twoDigits).second(.omitted)
//                                    if true || cal.isDate(range.lowerBound, inSameDayAs: range.upperBound) {
//                                        return "\(range.lowerBound.formatted(startFormat)) – \(range.upperBound.addingTimeInterval(-1).formatted(timeOnly))"
//                                    } else {
//                                        return "\(range.lowerBound.formatted(startFormat)) – \(range.upperBound.addingTimeInterval(-1).formatted(startFormat))"
//                                    }
//                                }())
//                            }
//                        }
//                    }
//                }
//            }
//        case .processingFailed:
//            EmptyView()
//        }
    }
    
    init(timeRange: HealthKitQueryTimeRange) {
        self.timeRange = timeRange
        self._sleepAnalysis = .init(.sleepAnalysis, timeRange: timeRange)
    }
    
    @ChartContentBuilder
    private func chartContent(for sleepSessions: [SleepSession]) -> some ChartContent {
        ForEach(sleepSessions, id: \.self) { session in
            BarMark(
                x: .value("Date", cal.makeNoon(session.endDate)),
                y: .value("Time Asleep", session.totalTimeAsleep / TimeConstants.hour),
                width: .automatic
            )
            .foregroundStyle(Color.blue)
        }
        if let xSelection,
           case let sessionsForDay = sleepSessions.filter({ cal.isDate(xSelection, inSameDayAs: cal.makeNoon($0.endDate)) }),
           !sessionsForDay.isEmpty {
            ChartHighlightRuleMark(
                x: .value("Selected", xSelection, unit: .day, calendar: cal),
                primaryText: { () -> String in
                    print("CALC DURATION TEXT")
                    let totalDuration = sessionsForDay.reduce(0) { $0 + $1.totalTimeAsleep }
                    let hours = Int(totalDuration / TimeConstants.hour)
                    let minutes = Int(totalDuration.truncatingRemainder(dividingBy: TimeConstants.hour) / TimeConstants.minute)
                    return "\(hours) hr \(minutes) min"
                }(),
                secondaryText: xSelection.formatted(.dateTime.calendar(cal).omittingTime())
            )
//            RuleMark(x: .value("Selected", xSelection, unit: .day, calendar: cal))
//                .foregroundStyle(Color.gray.opacity(0.3))
//                .offset(yStart: -10)
//                .zIndex(-1)
//                .annotation(
//                    position: AnnotationPosition.top,
//                    alignment: Alignment.center,
//                    spacing: 0,
//                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
//                ) { (context: AnnotationContext) in
//                    VStack(alignment: .leading) {
//                        Text(xSelection, format: .dateTime.calendar(cal).omittingTime())
//                            .font(.subheadline)
//                        let totalDuration = sessionsForDay.reduce(0) { $0 + $1.totalTimeAsleep }
//                        let hours = Int(totalDuration / TimeConstants.hour)
//                        let minutes = Int(totalDuration.truncatingRemainder(dividingBy: TimeConstants.hour) / TimeConstants.minute)
//                        Text("\(hours) hr \(minutes) min")
//                            .font(.headline)
//                    }
//                    .padding(4)
//                    .background(Color.gray.opacity(0.5))
//                    .background(.background)
//                    .clipShape(RoundedRectangle(cornerRadius: 4))
//                }
        }
    }
    
    private func processSleepSessions() -> SleepData {
        do {
            return .sleepSessions(try sleepAnalysis.splitIntoSleepSessions())
        } catch {
            return .processingFailed(error)
        }
    }
}


extension Range where Bound == Date {
    func displayText(using calendar: Calendar) -> String {
        let format: Date.FormatStyle = .dateTime.omittingTime().calendar(calendar)
        // TODO: give this a nice text (eg: "Today", "Current Week", "last N days", etc)
        // would it maybe make sense to have a "TimeRangeLabel"?
        return "\(lowerBound.formatted(format)) – \(upperBound.addingTimeInterval(-1).formatted(format))"
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
