//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziViews
import SwiftData
import SwiftUI


struct HeartHealthDashboard: View {
    struct AddNewSampleDescriptor: Identifiable {
        let keyPath: KeyPath<CVHScore, ScoreResult>
        var id: ObjectIdentifier { .init(keyPath) }
    }
    
    private struct ScoreResultToExplain: Identifiable {
        let keyPath: KeyPath<CVHScore, ScoreResult>
        let result: ScoreResult
        var id: ObjectIdentifier { .init(keyPath) }
    }
    
    @CVHScore private var cvhScore
    
    @Environment(NewsManager.self)
    private var newsManager
    
    @State private var addNewSampleDescriptor: AddNewSampleDescriptor?
    @State private var browseCustomHealthSamplesInput: CustomHealthSample.SampleType?
    @State private var presentedArticle: Article?
    @State private var scoreResultToExplain: ScoreResultToExplain?
    
    @State private var dbgShowExtendedHealthDashboard = false
    
    var body: some View {
        healthDashboard
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("E") {
                        dbgShowExtendedHealthDashboard = true
                    }
                }
            }
    }
    
    @ViewBuilder var healthDashboard: some View {
        HealthDashboard(layout: [
            .large(sectionTitle: nil, content: {
                topSection
            }),
            .grid(sectionTitle: "", components: [
                makeGridComponent(for: \.dietScore),
                makeGridComponent(for: \.bodyMassIndexScore),
                makeGridComponent(for: \.physicalExerciseScore),
                makeGridComponent(for: \.bloodLipidsScore),
                makeGridComponent(for: \.nicotineExposureScore),
                makeGridComponent(for: \.bloodGlucoseScore),
                makeGridComponent(for: \.sleepHealthScore),
                makeGridComponent(for: \.bloodPressureScore)
            ])
        ], footer: {
            Section("Further Reads") {
                ForEach(newsManager.articles) { article in
                    Button {
                        presentedArticle = article
                    } label: {
                        ArticleCard(article: article)
                            .frame(height: 117)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: HealthDashboardConstants.gridComponentCornerRadius))
                    .padding(.horizontal)
                }
            }
        })
        .navigationTitle("Heart Health Dashboard")
        .sheet(item: $addNewSampleDescriptor) { descriptor in
            NavigationStack {
                Self.addSampleView(for: descriptor.keyPath)
            }
        }
        .sheet(item: $browseCustomHealthSamplesInput) { sampleType in
            NavigationStack {
                CustomHealthSamplesBrowser(sampleType)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            DismissButton()
                        }
                    }
            }
        }
        .sheet(item: $presentedArticle) { article in
            ArticleSheet(article: article)
        }
        .sheet(item: $scoreResultToExplain) { (input: ScoreResultToExplain) in
            NavigationStack {
                DetailedHealthStatsView(
                    scoreResult: input.result,
                    cvhKeyPath: input.keyPath
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        DismissButton()
                    }
                }
            }
        }
        .sheet(isPresented: $dbgShowExtendedHealthDashboard) {
            NavigationStack {
                extendedDashboard
            }
        }
    }
    
    @ViewBuilder private var extendedDashboard: some View {
        let layout: HealthDashboardLayout = [
            HealthDashboardLayout.Block.grid(sectionTitle: "TITLE1", components: [
                .init(.stepCount, style: .chart(.init(chartType: .bar, aggregationInterval: .hour)), enableSelection: true),
                .init(.heartRate, style: .chart(.init(chartType: .point(area: 5), aggregationInterval: .init(.init(minute: 15))))),
                .sleepAnalysis(style: .singleValue(.mostRecentSample)),
                .sleepAnalysis(style: .singleValue(.aggregated(.sum))),
                .init(.heartRate, style: .singleValue(.aggregated(.min))),
                .init(.heartRate, style: .singleValue(.aggregated(.max)))
            ])
        ]
        HealthDashboard(layout: layout)
    }
    
    
    @ViewBuilder private var topSection: some View {
        Text("Overall Cardiovascular Health")
        Gauge2(
            lineWidth: .relative(1.5),
            gradient: .redToGreen,
            progress: cvhScore
        ) {
            if let cvhScore, !cvhScore.isNaN {
                Text(Int(cvhScore * 100), format: .number)
                    .font(.system(size: 27, weight: .medium))
            } else {
                Text("")
            }
        } minimumValueText: {
            Text("0")
                .font(.callout)
        } maximumValueText: {
            Text("100")
                .font(.callout)
        }
        .frame(width: 100, height: 100)
    }
    
    private func makeGridComponent(
        for scoreKeyPath: KeyPath<CVHScore, ScoreResult>
    ) -> HealthDashboardLayout.GridComponent {
        let score = $cvhScore[keyPath: scoreKeyPath]
        return .custom(title: score.sampleType.displayTitle) {
            if let scoreValue = score.score {
                VStack {
                    Gauge2(lineWidth: .default, gradient: .redToGreen, progress: scoreValue) {
                        Text(Int(scoreValue * 100), format: .number)
                            .font(.caption2)
                    }
                    .frame(width: 50, height: 50)
                    if let date = score.timeRange?.upperBound {
                        Text(date, format: .dateTime)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No data")
                    .foregroundStyle(.secondary)
            }
        } onTap: {
            scoreResultToExplain = .init(keyPath: scoreKeyPath, result: score)
        } contextMenu: {
            if Self.canAddSample(for: scoreKeyPath) {
                Button {
                    addNewSample(for: scoreKeyPath)
                } label: {
                    Label("Add Sample", systemSymbol: .plusSquare)
                }
            }
            Divider()
            Button {
                scoreResultToExplain = .init(keyPath: scoreKeyPath, result: score)
            } label: {
                Label("Details", systemSymbol: .infoCircle)
            }
            switch score.sampleType {
            case .healthKit:
                EmptyView()
            case .custom(let sampleType):
                Button {
                    browseCustomHealthSamplesInput = sampleType
                } label: {
                    Label("Browse Samples", systemSymbol: .listDash)
                }
            }
        }
    }
    
    private func addNewSample(for keyPath: KeyPath<CVHScore, ScoreResult>) {
        if Self.canAddSample(for: keyPath) {
            addNewSampleDescriptor = .init(keyPath: keyPath)
        }
    }
}


extension HeartHealthDashboard {
    private static let cvhKeyPathsWithDataEntryEnabled: Set<KeyPath<CVHScore, ScoreResult>> = [
        \.dietScore,
        \.bodyMassIndexScore,
//        \.physicalExerciseScore,
        \.bloodLipidsScore,
        \.nicotineExposureScore,
        \.bloodGlucoseScore,
//        \.sleepHealthScore,
        \.bloodPressureScore
    ]
    
    static func canAddSample(for keyPath: KeyPath<CVHScore, ScoreResult>) -> Bool {
        cvhKeyPathsWithDataEntryEnabled.contains(keyPath)
    }
    
    @ViewBuilder
    static func addSampleView(for keyPath: KeyPath<CVHScore, ScoreResult>) -> some View {
        switch keyPath {
        case \.dietScore:
            Text("Unable to find Questionnaire")
        case \.bodyMassIndexScore:
            SaveBMISampleView()
        case \.bloodLipidsScore:
            SaveQuantitySampleView(sampleType: .bloodLipids)
        case \.nicotineExposureScore:
            NicotineExposureEntryView()
        case \.bloodGlucoseScore:
            SaveQuantitySampleView(sampleType: .bloodGlucose)
        case \.bloodPressureScore:
            SaveBloodPressureSampleView()
        default:
            EmptyView()
        }
    }
}
