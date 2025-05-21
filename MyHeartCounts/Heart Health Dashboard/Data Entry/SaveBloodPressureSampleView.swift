//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SpeziHealthKit
import SpeziViews
import SwiftUI


struct SaveBloodPressureSampleView: View {
    @Environment(HealthKit.self)
    private var healthKit
    @Environment(\.dismiss)
    private var dismiss
    
    @State private var viewState: ViewState = .idle
    @State private var date: Date = .now
    @State private var systolic: Int?
    @State private var diastolic: Int?
    
    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $date)
                makeRow(for: $systolic, sampleType: .bloodPressureSystolic)
                makeRow(for: $diastolic, sampleType: .bloodPressureDiastolic)
            }
        }
        .navigationTitle("Enter Blood Pressure")
        .viewStateAlert(state: $viewState)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                AsyncButton("Save", state: $viewState) {
                    try await save()
                    dismiss()
                }
                .bold()
                .disabled(systolic == nil || diastolic == nil)
            }
        }
    }
    
    
    private func makeRow(for value: Binding<Int?>, sampleType: SampleType<HKQuantitySample>) -> some View {
        QuantityInputRow(title: sampleType.displayTitle, value: value, sampleType: sampleType)
    }
    
    private func save() async throws {
        guard let systolic, let diastolic else {
            return
        }
        let correlation = HKCorrelation(
            type: SampleType.bloodPressure.hkSampleType,
            start: date,
            end: date,
            objects: [
                HKQuantitySample(
                    type: SampleType.bloodPressureSystolic.hkSampleType,
                    quantity: HKQuantity(unit: SampleType.bloodPressureSystolic.displayUnit, doubleValue: Double(systolic)),
                    start: date,
                    end: date
                ),
                HKQuantitySample(
                    type: SampleType.bloodPressureDiastolic.hkSampleType,
                    quantity: HKQuantity(unit: SampleType.bloodPressureDiastolic.displayUnit, doubleValue: Double(diastolic)),
                    start: date,
                    end: date
                )
            ]
        )
        try await healthKit.save(correlation)
    }
}
