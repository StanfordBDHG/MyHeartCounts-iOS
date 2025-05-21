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


struct SaveQuantitySampleView: View {
    @Environment(HealthKit.self)
    private var healthKit
    @Environment(\.dismiss)
    private var dismiss
    
    let sampleType: SampleType<HKQuantitySample>
    @State private var startDate: Date = .now
    @State private var endDate: Date = .now
    @State private var value: Double?
    @State private var viewState: ViewState = .idle
    @FocusState private var valueFieldIsFocused: Bool
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Sample Type", value: sampleType.displayTitle)
                DatePicker("Start Date", selection: $startDate)
                DatePicker("End Date", selection: $endDate)
                QuantityInputRow(title: "Value", value: $value, sampleType: sampleType)
                    .focused($valueFieldIsFocused)
            }
        }
        .navigationTitle("Add Sample")
        .viewStateAlert(state: $viewState)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                DismissButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                AsyncButton("Add", state: $viewState) {
                    try await save()
                    dismiss()
                }
                .disabled(value == nil && endDate >= startDate)
            }
        }
        .onAppear {
            valueFieldIsFocused = true
        }
    }
    
    private func save() async throws {
        guard let value else {
            return
        }
        let sample = HKQuantitySample(
            type: sampleType.hkSampleType,
            quantity: HKQuantity(unit: sampleType.displayUnit, doubleValue: value),
            start: startDate,
            end: endDate
        )
        try await healthKit.save(sample)
    }
}


extension HKQuantity {
    func valuesForFeetAndInches() -> (feet: Int, inches: Double) {
        let oneFeetInInches = Measurement(value: 1, unit: UnitLength.feet).converted(to: .inches).value
        let totalFeet = self.doubleValue(for: .foot())
        let totalInches = self.doubleValue(for: .inch())
        let feet = Int(totalFeet)
        guard feet != 0 else {
            return (0, totalInches)
        }
        let inches = totalInches.remainder(dividingBy: Double(feet) * oneFeetInInches).rounded()
        precondition(inches != -1)
        return (feet, inches)
    }
}
