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
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziStudy
import SpeziViews
import SwiftUI


/*
 known issues:
 - line chart doesn't display anything if it has only a single data point (since there is nothing to connect it to..., apparently)
 */

struct DetailedHealthStatsView: View {
    private enum Input {
        case scoreResult(result: ScoreResult, keyPath: KeyPath<CVHScore, ScoreResult>)
    }
    
    // swiftlint:disable attributes
    @Environment(Account.self) private var account: Account?
    @Environment(StudyManager.self) private var studyManager
    @Environment(AccountFeatureFlags.self) private var accountFeatureFlags
    // swiftlint:enable attributes
    
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
            if let explainer = explainerText(for: sampleType) {
                let document = (try? MarkdownDocument(processing: explainer))
                    ?? MarkdownDocument(metadata: [:], blocks: [.markdown(id: nil, rawContents: explainer)])
                Section {
                    FurtherReadingSection(
                        title: "About \(sampleType.displayTitle)",
                        document: document
                    )
                }
            }
            if accountFeatureFlags.isDebugModeEnabled, case let .custom(sampleType) = sampleType {
                Section("Debug") {
                    NavigationLink("All Samples") {
                        BrowseFirestoreSamplesView(sampleType: sampleType)
                    }
                }
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
                        HeartHealthDashboard.addSampleView(for: keyPath, locale: Locale.current)
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
                return .firebase(sampleType)
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
                case .custom:
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
                Gauge(
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
    
    private let title: LocalizedStringResource
    private let document: MarkdownDocument
    private let link: URL?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title)
            MarkdownView(markdownDocument: document)
        }
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
        }
    }
    
    init(title: LocalizedStringResource, document: MarkdownDocument) {
        self.title = title
        self.document = document
        self.link = document.metadata["link"].flatMap { try? URL($0, strategy: .url) }
    }
}


extension DetailedHealthStatsView {
    private func explainerText(for sampleType: MHCSampleType) -> String? { // swiftlint:disable:this cyclomatic_complexity
        let imp = { (key: String) -> String? in
            let fileRef = StudyBundle.FileReference(category: .init(rawValue: "hhdExplainer"), filename: key, fileExtension: "md")
            guard let studyBundle = studyManager.studyEnrollments.first?.studyBundle,
                  let url = studyBundle.resolve(fileRef, in: studyManager.preferredLocale) else {
                return nil
            }
            return try? String(contentsOf: url, encoding: .utf8)
        }
        return switch sampleType {
        case .custom(.dietMEPAScore):
            imp("DietScore")
        case .custom(.bloodLipids):
            imp("BloodLipids")
        case .custom(.nicotineExposure):
            imp("NicotineExposure")
        case .healthKit(.quantity(.bodyMassIndex)):
            imp("BMI")
        case .healthKit(.quantity(.appleExerciseTime)):
            imp("ExerciseMinutes")
        case .healthKit(.quantity(.stepCount)):
            imp("StepCount")
        case .healthKit(.quantity(.bloodGlucose)):
            imp("BloodGlucose")
        case .healthKit(.category(.sleepAnalysis)):
            imp("Sleep")
        case .healthKit(.correlation(.bloodPressure)):
            imp("BloodPressure")
        default:
            nil
        }
    }
}


private struct BrowseFirestoreSamplesView: View {
    @MHCFirestoreQuery<QuantitySample> private var samples: [QuantitySample]
    
    var body: some View {
        Form {
            List(samples) { sample in
                NavigationLink {
                    Form {
                        LabeledContent("id", value: sample.id.uuidString)
                        LabeledContent("sampleType", value: sample.sampleType.displayTitle)
                        LabeledContent("unit", value: sample.unit.unitString)
                        LabeledContent("value", value: sample.value, format: .number)
                        LabeledContent("startDate", value: sample.startDate, format: .dateTime)
                        LabeledContent("endDate", value: sample.endDate, format: .dateTime)
                    }
                } label: {
                    HStack {
                        Text(sample.startDate, format: .dateTime)
                        Spacer()
                        Text(sample.valueAndUnitDescription())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    init(sampleType: CustomQuantitySampleType) {
        _samples = .init(sampleType: sampleType, timeRange: .ever)
    }
}
