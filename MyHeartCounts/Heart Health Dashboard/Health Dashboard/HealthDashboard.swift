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
import SpeziHealthKit
import SpeziHealthKitUI
import SwiftData
import SwiftUI


extension Gradient {
    static let greenToRed = Gradient(colors: [.green, .yellow, .orange, .red])
    static let redToGreen = Gradient(colors: [.red, .orange, .yellow, .green])
}



struct StyledGauge: View {
    private let value: Double
    private let range: ClosedRange<Double>
    
    init(value: Double, in range: ClosedRange<Double>) {
        self.value = value
        self.range = range
    }


    var body: some View {
        SwiftUI.Gauge(value: value, in: range) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
        } currentValueLabel: {
            Text("\(Int(value))")
                .foregroundColor(Color.green)
        } minimumValueLabel: {
            Text("\(Int(range.lowerBound))")
                .foregroundColor(Color.green)
        } maximumValueLabel: {
            Text("\(Int(range.upperBound))")
                .foregroundColor(Color.red)
        }
//        .gaugeStyle(CircularGaugeStyle(tint: gradient))
        .gaugeStyle(.accessoryCircular)
    }
}



struct HealthDashboard: View {
    private static let tmp_enableDebugGaugesSection = false
    
    // TODO good names for all of these!!!
    typealias SampleTypeGoalProvider = @MainActor (QuantitySample.SampleType) -> Achievement.ResolvedGoal?
    typealias AddSampleHandler = @MainActor (MHCSampleType) -> Void
    
    private let layout: HealthDashboardLayout
    private let goalProvider: SampleTypeGoalProvider?
    private let addSampleHandler: AddSampleHandler?
    
    init(
//        @HealthDashboardLayoutBuilder layout: () -> HealthDashboardLayout,
        layout: HealthDashboardLayout,
        goalProvider: SampleTypeGoalProvider? = nil,
        addSampleHandler: AddSampleHandler? = nil
    ) {
        self.layout = layout
        self.goalProvider = goalProvider
        self.addSampleHandler = addSampleHandler
    }
    
    @State private var tmp_gaugeValue: Double = 1 / 3
    
    var body: some View {
        ScrollView {
            ForEach(0..<layout.blocks.endIndex, id: \.self) { blockIdx in
                let block = layout.blocks[blockIdx]
                Section {
                    switch block.content {
                    case .grid(let components):
                        makeGrid(with: components)
                    case .largeChart(let component):
                        makeChart(for: component)
                    case .largeCustom(let makeView):
                        makeView()
                    }
                } header: {
                    if let title = block.title {
                        HStack {
                            Text(title)
                                .font(.title3.bold())
                            Spacer()
                        }
                        .padding(.top, 17)
                    }
                }
            }
            .padding(.horizontal)
            if Self.tmp_enableDebugGaugesSection {
                gaugeDebugSection
                    .padding(.horizontal)
            }
        }
        .makeBackgroundMatchFormBackground()
    }
    
    @ViewBuilder private var gaugeDebugSection: some View {
        Color.clear.frame(height: 20)
        HStack {
            Spacer()
            StyledGauge(value: tmp_gaugeValue, in: 0...1)
                .background(.red.opacity(0.2))
            Spacer()
            Gauge2(gradient: .greenToRed, progress: tmp_gaugeValue)
                .frame(width: 58, height: 58)
                .background(.red.opacity(0.2))
            Spacer()
            ZStack {
                StyledGauge(value: tmp_gaugeValue, in: 0...1)
                Gauge2(gradient: .greenToRed, progress: tmp_gaugeValue)
                    .opacity(0.5)
                    .frame(width: 58, height: 58)
            }
            Spacer()
            Gauge(progress: tmp_gaugeValue, gradient: .redToGreen, backgroundColor: .clear, lineWidth: 4)
                .frame(width: 40, height: 40)
                .background(.red.opacity(0.2))
            Spacer()
        }
        
        HStack {
            Slider(value: $tmp_gaugeValue, in: 0...1)
            Text("\(tmp_gaugeValue, specifier: "%.2f")")
                .monospacedDigit()
        }
        HStack {
            ForEach(Array(stride(from: 0, through: 1, by: 0.1)), id: \.self) { step in
                Button("\(step, specifier: "%.1f")") {
                    withAnimation {
                        tmp_gaugeValue = step
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func makeGrid(with components: [HealthDashboardLayout.GridComponent]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12, alignment: .top),
            GridItem(.flexible(), alignment: .top)
        ]
        LazyVGrid(columns: columns, alignment: .center, spacing: 12, pinnedViews: .sectionHeaders) {
            ForEach(0..<components.endIndex, id: \.self) { idx in
                makeView(for: components[idx])
            }
        }
    }
    
    
    @ViewBuilder
    private func makeView(for component: HealthDashboardLayout.GridComponent) -> some View {
        let view = Group {
            switch component {
            case .quantityDisplay(let config):
                makeComponentView(for: config)
            case .custom(let config):
                SmallGridCell(title: config.title) {
                    config.content()
                }
            }
        }
        let tapAction = { () -> (@MainActor () -> Void)? in
            switch component {
            case .quantityDisplay(let config):
                if config.allowAddingSamples, let addSampleHandler {
                    switch config.dataSource {
                    case .healthKit(let sampleType):
                        { @MainActor in
                            addSampleHandler(MHCSampleType.healthKit(sampleType))
                        }
                    case .custom(let dataSource):
                        // TODO extend the addSampleHandler to also support this!!!
                        nil
                    }
                } else {
                    nil
                }
            case .custom(let config):
                config.tapAction
            }
        }()
        if let tapAction {
            Button(action: tapAction) {
                view
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
        } else {
            view
        }
    }
    
    
    @ViewBuilder
    private func makeComponentView(for config: HealthDashboardLayout.GridComponent.QuantityDisplayComponentConfig) -> some View {
        switch config.dataSource {
        case .healthKit(.quantity(let sampleType)):
            HealthDashboardQuantityComponentGridCell(inputSampleType: .healthKit(sampleType), config: config)
        case .custom(let dataSource):
            HealthDashboardQuantityComponentGridCell(inputSampleType: .custom(dataSource), config: config)
        case .healthKit(.category(.sleepAnalysis)):
            SleepAnalysisGridCell()
        case .healthKit(.correlation(.bloodPressure)):
            BloodPressureGridCell()
        case .healthKit:
            // TODO?
            EmptyView()
        }
    }
    
    
    @ViewBuilder
    private func makeChart(
        for component: HealthDashboardLayout.LargeChartComponent
    ) -> some View {
//        let config = component.chartConfig.resolved(for: sampleType, in: timeRange)
        // TODO!
        EmptyView()
    }
}



enum StatisticsQueryAggregationKind { // TODO why not reuse the type from SpeziHealthKit?
    case sum, average
    
    init(_ other: HKQuantityAggregationStyle) {
        switch other {
        case .cumulative:
            self = .sum
        case .discreteArithmetic:
            self = .average
        case .discreteTemporallyWeighted:
            self = .average
        case .discreteEquivalentContinuousLevel:
            fatalError("Currently not supported")
        @unknown default:
            fatalError("Currently not supported")
        }
    }
    
    init(_ sampleType: MHCQuantitySampleType) {
        switch sampleType {
        case .healthKit(let sampleType):
            self.init(sampleType.hkSampleType.aggregationStyle)
        case .custom(let sampleType):
            self = sampleType.aggregationKind
        }
    }
}


enum TimeConstants {
    static let minute: TimeInterval = 60
    static let hour = 60 * minute
    static let day = 24 * hour
    static let week = 7 * day
    static let month = 31 * day
    static let year = 365 * day
}


extension FloatingPoint {
    var isWholeNumber: Bool {
        rounded() == self // TODO is this correct? a good idea?
    }
}


struct SleepAnalysisGridCell: View {
    @HealthKitQuery(.sleepAnalysis, timeRange: .last(days: 4))
    private var sleepAnalysis
    
    var body: some View {
        let sleepSessions = try! sleepAnalysis.splitIntoSleepSessions() // swiftlint:disable:this force_try
        
        HealthDashboard.SmallGridCell(title: $sleepAnalysis.sampleType.displayTitle) {
            EmptyView() // TODO?
        } content: {
            if let session = sleepSessions.last {
                HealthDashboard.QuantityLabel(input: .init(
                    valueString: String(format: "%.1f", session.totalTimeAsleep / 60 / 60),
                    unitString: HKUnit.hour().unitString,
                    timeRange: session.timeRange
                ))
            }
        }
    }
}

struct BloodPressureGridCell: View {
    @HealthKitQuery(.bloodPressure, timeRange: .last(months: 6))
    private var samples
    
    var body: some View {
        HealthDashboard.SmallGridCell(title: $samples.sampleType.displayTitle) {
            EmptyView() // TODO?
        } content: {
            if let sample = samples.last,
               let systolic = sample.firstSample(ofType: .bloodPressureSystolic),
               let diastolic = sample.firstSample(ofType: .bloodPressureDiastolic) {
                let unit = SampleType.bloodPressureSystolic.displayUnit
                HealthDashboard.QuantityLabel(input: .init(
                    valueString: "\(Int(systolic.quantity.doubleValue(for: unit)))/\(Int(diastolic.quantity.doubleValue(for: unit)))",
                    unitString: unit.unitString,
                    timeRange: sample.timeRange
                ))
            }
        }
    }
}


extension HKCorrelation {
    func firstSample<Sample>(ofType sampleType: SampleType<Sample>) -> Sample? {
        for sample in self.objects {
            if let sample = sample as? Sample, sample.is(sampleType) {
                return sample
            }
        }
        return nil
    }
}



/// Compare two sample types, based on their identifiers
@inlinable public func ~= (pattern: SampleType<some Any>, value: SampleTypeProxy) -> Bool {
    pattern.id == value.id
}


extension AnySampleType {
    var preferredTintColorForDisplay: Color? {
        switch SampleTypeProxy(self) {
        case .heartRate, .activeEnergyBurned:
            Color.red
        case .bloodOxygen:
            Color.blue
        case .bloodPressure, .bloodPressureSystolic, .bloodPressureDiastolic:
            Color.red
        case .stepCount, .walkingStepLength, .distanceWalkingRunning, .runningStrideLength, .stairAscentSpeed, .stairDescentSpeed, .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage:
            Color.orange
        default:
            nil
        }
    }
}


extension QuantitySample.SampleType {
    var preferredTintColorForDisplay: Color? {
        switch self {
        case .healthKit(let sampleType):
            sampleType.preferredTintColorForDisplay
        case .custom(let sampleType):
            sampleType.preferredTintColor
        }
    }
}



extension HealthKitStatisticsQuery.AggregationInterval {
    static func `for`(_ queryTimeRange: HealthKitQueryTimeRange) -> Self {
        let cal = Calendar.current
        let components = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: queryTimeRange.range.lowerBound,
            to: queryTimeRange.range.upperBound
        )
        return .init(components)
    }
}
