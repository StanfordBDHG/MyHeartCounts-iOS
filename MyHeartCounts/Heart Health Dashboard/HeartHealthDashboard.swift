//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import SFSafeSymbols
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziQuestionnaire
import SpeziStudy
import SpeziViews
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
    
    // swiftlint:disable attributes
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var cal
    @Environment(StudyManager.self) private var studyManager
    // swiftlint:enable attributes
    
    @CVHScore private var cvhScore
    
    @State private var addNewSampleDescriptor: AddNewSampleDescriptor?
    @State private var presentedArticle: Article?
    @State private var scoreResultToExplain: ScoreResultToExplain?
    @State private var isPresentingPastTimedWalkTestResults = false
    
    var body: some View {
        Form {
            healthDashboard
        }
    }
    
    @ViewBuilder var healthDashboard: some View {
        Section {
            Text("HEART_HEALTH_DASHBOARD_HEADER")
                .listRowInsets(.zero)
                .padding([.top, .horizontal])
                .listRowBackground(Color.clear)
                .sheet(item: $addNewSampleDescriptor) { descriptor in
                    Self.addSampleSheet(for: descriptor.keyPath)
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
                .sheet(isPresented: $isPresentingPastTimedWalkTestResults) {
                    NavigationStack {
                        PastTimedWalkTestResults()
                            .taskPerformingAnchor()
                    }
                }
        }
        HealthDashboard(
            layout: [
                .large {
                    topSection
                },
                .grid(
                    footer: "HHD_APPLE_WATCH_REQUIRED_FOOTER"
                ) {
                    makeGridComponent(for: \.dietScore)
                    makeGridComponent(for: \.bodyMassIndexScore)
                    switch $cvhScore.preferredExerciseMetric {
                    case .exerciseMinutes:
                        makeGridComponent(for: \.physicalExerciseScore)
                    case .stepCount:
                        makeGridComponent(for: \.stepCountScore)
                    }
                    makeGridComponent(for: \.bloodLipidsScore)
                    makeGridComponent(for: \.nicotineExposureScore)
                    makeGridComponent(for: \.bloodGlucoseScore)
                    makeGridComponent(for: \.sleepHealthScore)
                    makeGridComponent(for: \.bloodPressureScore)
                }
            ]
        )
        .makeBackgroundMatchFormBackground()
        learnMoreSection
        pastDataSection
    }
    
    
    @ViewBuilder private var topSection: some View {
        HStack {
            Spacer()
            Gauge(
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
            Spacer()
        }
    }
    
    @ViewBuilder private var learnMoreSection: some View {
        if let learnMoreText = studyManager.localizedMarkdown(for: "LearnMore", in: .hhdExplainer) {
            Section("Learn More") {
                MarkdownView(markdownDocument: .init(metadata: [:], blocks: [.markdown(id: nil, rawContents: learnMoreText)]))
            }
        }
    }
    
    private var pastDataSection: some View {
        Section("Past Data") {
            Button {
                isPresentingPastTimedWalkTestResults = true
            } label: {
                HStack {
                    Text("PAST_TIMED_WALKING_RUNNING_TEST_RESULTS_BUTTON_TITLE")
                        .foregroundStyle(colorScheme.textLabelForegroundStyle)
                    Spacer()
                    DisclosureIndicator()
                }
            }
        }
    }
    
    private func makeGridComponent(
        for scoreKeyPath: KeyPath<CVHScore, ScoreResult>
    ) -> HealthDashboardLayout.GridComponent {
        let score = $cvhScore[keyPath: scoreKeyPath]
        return .custom(title: score.sampleType.displayTitle) {
            if let scoreValue = score.score {
                VStack {
                    Gauge(lineWidth: .default, gradient: .redToGreen, progress: scoreValue) {
                        Text(Int(scoreValue * 100), format: .number)
                            .font(.caption2)
                    }
                    .frame(width: 50, height: 50)
                    if let timeRange = score.timeRange {
                        Text(timeRange.displayText(using: cal))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No Data…")
                    .foregroundStyle(.secondary)
            }
        } onTap: {
            if true {
                addNewSample(for: scoreKeyPath)
            } else {
                scoreResultToExplain = .init(keyPath: scoreKeyPath, result: score)
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
        \.bloodLipidsScore,
        \.nicotineExposureScore,
        \.bloodGlucoseScore,
        \.bloodPressureScore
    ]
    
    static func canAddSample(for keyPath: KeyPath<CVHScore, ScoreResult>) -> Bool {
        cvhKeyPathsWithDataEntryEnabled.contains(keyPath)
    }
    
    
    static func addSampleSheet(for keyPath: KeyPath<CVHScore, ScoreResult>) -> some View {
        NavigationStack {
            switch keyPath {
            case \.nicotineExposureScore:
                HealthDashboardQuestionnaireView(questionnaireName: "NicotineExposure")
            case \.dietScore:
                HealthDashboardQuestionnaireView(questionnaireName: "Diet")
            case \.bodyMassIndexScore:
                SaveBMISampleView()
            case \.bloodLipidsScore:
                SaveQuantitySampleView(sampleType: MHCQuantitySampleType.custom(.bloodLipids))
            case \.bloodGlucoseScore:
                SaveQuantitySampleView(sampleType: MHCQuantitySampleType.healthKit(.bloodGlucose))
            case \.bloodPressureScore:
                SaveBloodPressureSampleView()
            default:
                EmptyView()
            }
        }
    }
}


private struct HealthDashboardQuestionnaireView: View {
    @Environment(MyHeartCountsStandard.self)
    private var standard
    
    @Environment(StudyManager.self)
    private var studyManager
    
    @Environment(\.dismiss)
    private var dismiss
    
    let questionnaireName: String
    @State private var questionnaire: Questionnaire?
    
    var body: some View {
        Group {
            if let questionnaire {
                QuestionnaireView(questionnaire: questionnaire) { result in
                    switch result {
                    case .completed(let response):
                        await standard.add(response)
                    case .cancelled, .failed:
                        break
                    }
                    dismiss()
                }
            } else {
                ContentUnavailableView("Unable to find Questionnaire", systemSymbol: .exclamationmarkTriangle) // ???
            }
        }
        .task {
            loadQuestionnaire()
        }
    }
    
    private func loadQuestionnaire() {
        guard let studyBundle = studyManager.studyEnrollments.first?.studyBundle else {
            return
        }
        questionnaire = studyBundle.questionnaire(named: questionnaireName, in: studyManager.preferredLocale)
    }
}
