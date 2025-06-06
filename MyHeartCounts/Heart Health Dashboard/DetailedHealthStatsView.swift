//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Charts
import Foundation
import SpeziAccount
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziViews
import SwiftData
import SwiftUI


/*
 known issues:
 - line chart doesn't display anything if it has only a single data point (since there is nothing to connect it to..., apparently)
 */

struct DetailedHealthStatsView: View {
    private enum Input {
        case scoreResult(result: ScoreResult, keyPath: KeyPath<CVHScore, ScoreResult>)
    }
    
    @Environment(\.modelContext)
    private var modelContext
    
    @Environment(Account.self)
    private var account: Account?
    
    private let sampleType: MHCSampleType
    private let input: Input
    @State private var isPresentingAddSampleSheet = false
    
    var body: some View {
        Form { // swiftlint:disable:this closure_body_length
            switch input {
            case .scoreResult(let result, keyPath: _):
                Section {
                    scoreResultBasedTopSection(for: result)
                }
                .listRowInsets(.zero)
                .listRowBackground(Color.clear)
            }
            
            Section {
                recentValuesChart
                    .frame(height: 220)
                    .listRowInsets(.zero)
            }
            
            switch input {
            case .scoreResult(let result, keyPath: _):
                Section("Score Result") {
                    scoreResultExplainer(for: result)
                }
            }
            
            Section {
                FurtherReadingSection(
                    title: "About Sleep",
                    body: """
                    Sleep provides insight into your sleep habits.
                    Sleep trackers and monitors can help you determine the amount of time you are in bed and asleep. These devices estimate your time in bed and your time asleep by analysing changes in physical activity, including movement during the night. You can also keep track of your sleep by entering your own estimation of your time in bed and time asleep manually.
                    The "In Bed" period reflects the time period you are lying in bed with the intention to sleep.
                    For most people, it starts when you turn the lights off and it ends when you get out of bed.
                    The "Asleep" period reflects the period(s) you are asleep.
                    """,
                    link: "https://stanford.edu"
                )
            }
            switch sampleType {
            case .healthKit:
                EmptyView()
            case .custom(let sampleType):
//                Section {
//                    NavigationLink("Browse Data") {
//                        CustomHealthSamplesBrowser(sampleType)
//                    }
//                }
                EmptyView() // ???
            }
        }
        .navigationTitle(sampleType.displayTitle)
        .toolbar {
            switch input {
            case .scoreResult(result: _, let keyPath):
                if HeartHealthDashboard.canAddSample(for: keyPath) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add Data") {
                            isPresentingAddSampleSheet = true
                        }
                    }
                }
            }
        }
        .transforming { view in
            switch input {
            case .scoreResult(result: _, let keyPath):
                view.sheet(isPresented: $isPresentingAddSampleSheet) {
                    NavigationStack {
                        HeartHealthDashboard.addSampleView(for: keyPath)
                    }
                }
            }
        }
    }
    
    
    @ViewBuilder private var recentValuesChart: some View {
        let timeRange: HealthKitQueryTimeRange = .last(days: 14) // 14!
        let dataSource = { () -> HealthDashboardLayout.DataSource? in
            switch sampleType {
            case .healthKit(let proxy):
                return .healthKit(proxy)
            case .custom(let sampleType):
                return FirestoreHealthDashboardDataSource(account: account, sampleType: sampleType, timeRange: timeRange).map { .custom($0) }
//                return CustomHealthSampleHealthDashboardDataSource(
//                    modelContext: modelContext,
//                    sampleType: sampleType,
//                    timeRange: timeRange
//                ).map { .custom($0) }
            }
        }()
        if let dataSource {
            // Note: we're creating a chart config here, but depending on the specific sample type it might end up getting discarded
            // (eg: if the sample type is sleepAnalyis, in which case it's not something we display via the normal chart)
            let chartConfig = { () -> HealthDashboardLayout.ChartConfig in
                switch sampleType {
                case .healthKit(.quantity(let sampleType)):
                    return .default(for: sampleType, in: timeRange)
                case .healthKit:
                    return .init(chartType: .line(), defaultAggregationIntervalFor: timeRange)
                case .custom(.bloodLipids), .custom(.dietMEPAScore), .custom(.nicotineExposure):
                    return .init(chartType: .line(), defaultAggregationIntervalFor: timeRange)
                }
            }()
            healthDashboardComponentView(
                for: .init(
                    dataSource: dataSource,
                    timeRange: timeRange,
                    style: .chart(chartConfig),
                    enableSelection: false
                ),
                withSize: .large
            )
            //        .padding() // Issue: some of them need padding, some dont :/
            .healthStatsChartHoverHighlightEnabled()
            .environment(\.showTimeRangeAsGridCellSubtitle, true)
        } else {
            HStack {
                Spacer()
                Text("Unable to load data")
                Spacer()
            }
        }
    }
    
    
    init(scoreResult: ScoreResult, cvhKeyPath: KeyPath<CVHScore, ScoreResult>) {
        self.sampleType = scoreResult.sampleType
        self.input = .scoreResult(result: scoreResult, keyPath: cvhKeyPath)
    }
    
    
    @ViewBuilder
    private func scoreResultBasedTopSection(for scoreResult: ScoreResult) -> some View { // swiftlint:disable:this function_body_length
        let spacing: Double = 24
        GeometryReader { geometry in // swiftlint:disable:this closure_body_length
            let gaugePartWidth = (geometry.size.width - spacing) * 0.37
            let leftPartWidth = geometry.size.width - spacing - gaugePartWidth
            HStack(spacing: spacing / 2 - 1) { // swiftlint:disable:this closure_body_length
                VStack(alignment: .leading) {
                    Text(sampleType.displayTitle)
                        .font(.headline)
                    if let value = scoreResult.inputValue {
                        HStack {
                            let valueDesc = { () -> String in
                                if let value = value as? any FloatingPoint & CVarArg {
                                    String(format: "%.2f", value)
                                } else {
                                    String(describing: value)
                                }
                            }()
                            Text(valueDesc)
                                .font(.system(.body).bold().monospacedDigit())
                            if let displayUnit = sampleType.displayUnit, displayUnit != .count() {
                                Text(displayUnit.unitString)
                                    .font(.footnote.smallCaps())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if let timeRange = scoreResult.timeRange {
                            Text(timeRange.upperBound.addingTimeInterval(-1), format: .dateTime)
                        }
                    }
                }
                .frame(width: leftPartWidth, alignment: .leading)
                Divider()
                    .frame(width: 1)
                Gauge2(
                    lineWidth: .relative(1.75),
                    gradient: .redToGreen,
                    progress: scoreResult.score
                ) {
                    if let score = scoreResult.score {
                        Text(Int(score * 100), format: .number)
                            .bold()
                    } else {
                        Text("")
                    }
                }
                .frame(width: 90, height: 90)
                .frame(width: gaugePartWidth, alignment: .center)
            }
        }
        .frame(height: 120)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func scoreResultExplainer(for scoreResult: ScoreResult) -> some View {
        ScoreExplanationView(scoreResult: scoreResult)
            .listRowBackground(Color.clear)
    }
}


/// Intended to be used as the content of a Form/List Section; displays information about how a Score is computed, and what the percise values mean.
private struct ScoreExplanationView: View {
    let scoreResult: ScoreResult
    
    var body: some View {
        switch scoreResult.definition.variant {
        case let .distinctMapping(_, elements):
            VStack(spacing: 8) {
                ForEach(elements, id: \.self) { element in
                    makeRow(for: element)
                }
            }
            .listRowInsets(.zero)
        case .range(let range):
            makeColorBar(didMatch: false, background: Gradient.redToGreen) {
                Text(range.lowerBound, format: .number)
                Spacer()
                Text(range.upperBound, format: .number)
            }
        case .custom(_, let textualRepresentation):
            Text(textualRepresentation)
        }
    }
    
    @ViewBuilder
    private func makeRow(for element: ScoreDefinition.Element) -> some View {
        let color = Gradient.redToGreen.color(at: element.score)
        let didMatch = { () -> Bool in
            if let inputValue = scoreResult.inputValue,
               case let ScoreDefinition.Variant.distinctMapping(default: _, elements) = scoreResult.definition.variant {
                element == elements.first { $0.matches(inputValue) }
            } else {
                false
            }
        }()
        makeColorBar(didMatch: didMatch, background: color.opacity(didMatch ? 1 : 0.9)) {
            Text(element.textualRepresentation)
            Spacer()
            if didMatch {
                Image(systemSymbol: .checkmarkCircle)
                    .accessibilityLabel("Matching Entry")
            }
            Text(Int(element.score * 100), format: .number)
        }
    }
    
    
    @ViewBuilder
    private func makeColorBar(didMatch: Bool, background: some ShapeStyle, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .foregroundStyle(.black)
        .font(.subheadline.weight(didMatch ? .semibold : .medium))
    }
}


private struct FurtherReadingSection: View {
    @Environment(\.openURL)
    private var openURL
    
    private let titleText: String?
    private let bodyText: String
    private let link: URL?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let titleText {
                Text(titleText)
                    .font(.title)
            }
            Text(bodyText)
            if let link {
                Button {
                    openURL(link)
                } label: {
                    HStack {
                        Text("Learn More")
                        Spacer()
                        Image(systemSymbol: .safari)
                            .accessibilityLabel("Open In Browser")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    init(title titleText: String? = nil, body bodyText: String, link: URL? = nil) { // swiftlint:disable:this function_default_parameter_at_end
        self.titleText = titleText
        self.bodyText = bodyText
        self.link = link
    }
}
