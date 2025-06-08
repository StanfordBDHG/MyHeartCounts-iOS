//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziQuestionnaire
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
    
    @CVHScore private var cvhScore
    
    @Environment(NewsManager.self)
    private var newsManager
    
    @State private var addNewSampleDescriptor: AddNewSampleDescriptor?
    @State private var presentedArticle: Article?
    @State private var scoreResultToExplain: ScoreResultToExplain?
    
    var body: some View {
        healthDashboard
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
                Self.addSampleView(for: descriptor.keyPath, locale: Locale.current)
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
    
    @ViewBuilder
    static func addSampleView(for keyPath: KeyPath<CVHScore, ScoreResult>, locale: Locale) -> some View {
        switch keyPath {
        case \.nicotineExposureScore:
            HealthDashboardQuestionnaireView(questionnaireName: "NicotineExposure")
        case \.dietScore:
            HealthDashboardQuestionnaireView(questionnaireName: "DietScoreMEPA")
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


private struct HealthDashboardQuestionnaireView: View {
    @Environment(\.locale)
    private var locale
    
    @Environment(MyHeartCountsStandard.self)
    private var standard
    
    @Environment(\.dismiss)
    private var dismiss
    
    let questionnaireName: String
    
    var body: some View {
        if let questionnaire = Bundle.main.localizedQuestionnaire(withName: questionnaireName, for: locale) {
            QuestionnaireView(questionnaire: questionnaire) { result in
                switch result {
                case .completed(let response):
                    await standard.add(response: response)
                case .cancelled, .failed:
                    break
                }
                dismiss()
            }
        } else {
            ContentUnavailableView("Unable to find Questionnaire", systemSymbol: .exclamationmarkTriangle) // ???
        }
    }
}
