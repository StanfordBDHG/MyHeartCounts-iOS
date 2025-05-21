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


/*
 - toggle
 - choice SC/MC
 - vlidation?
 - exporting?
 */


struct LifesEssential8: View {
    private struct AddNewSampleDescriptor: Identifiable {
        let keyPath: KeyPath<CVHScore, CVHScore.Score>
        var id: ObjectIdentifier { .init(keyPath) }
    }
    
    private static let cvhKeyPathsWithDataEntryEnabled: Set<PartialKeyPath<CVHScore>> = [
        \.dietScore,
        \.bodyMassIndexScore,
//        \.physicalExerciseScore,
        \.bloodLipidsScore,
        \.nicotineExposureScore,
        \.bloodGlucoseScore,
//        \.sleepHealthScore,
        \.bloodPressureScore
    ]
    
    @CVHScore private var cvhScore
    
//    @State private var sampleTypeToAdd: MHCSampleType?
    
    @State private var addNewSampleDescriptor: AddNewSampleDescriptor?
    
    var body: some View {
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
        ])
        .navigationTitle("Life's Essential 8")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                DismissButton()
            }
        }
        .sheet(item: $addNewSampleDescriptor) { addNewSampleDescriptor in
            NavigationStack {
                switch addNewSampleDescriptor.keyPath {
                case \.dietScore:
                    Text("TODO")
                case \.bodyMassIndexScore:
                    SaveBMISampleView()
                case \.bloodLipidsScore:
                    Text("TODO")
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
        for scoreKeyPath: KeyPath<CVHScore, CVHScore.Score>
    ) -> HealthDashboardLayout.GridComponent {
        let score = $cvhScore[keyPath: scoreKeyPath]
        return .custom(title: score.sampleType.displayTitle) {
            if let normalized = score.normalized {
                VStack {
                    Gauge2(lineWidth: .default, gradient: .redToGreen, progress: normalized) {
                        Text("\(Int(normalized * 100))%")
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
            addNewSampleDescriptor = .init(keyPath: scoreKeyPath)
        }
    }
}
