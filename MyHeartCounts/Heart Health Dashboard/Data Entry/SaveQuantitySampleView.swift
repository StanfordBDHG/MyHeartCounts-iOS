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
import SwiftData
import SwiftUI


struct SaveQuantitySampleView: View {
    @Environment(HealthKit.self)
    private var healthKit
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    
    private let sampleTypeTitle: String
    private let sampleTypeUnit: HKUnit
    
    private let save: @MainActor (Self) async throws -> Void
    @State private var startDate: Date = .now
    @State private var endDate: Date = .now
    @State private var value: Double?
    @State private var viewState: ViewState = .idle
    @FocusState private var valueFieldIsFocused: Bool
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Sample Type", value: sampleTypeTitle)
                DatePicker("Start Date", selection: $startDate)
                DatePicker("End Date", selection: $endDate)
                QuantityInputRow(title: "Value", value: $value, unit: sampleTypeUnit)
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
                    try await save(self)
                    dismiss()
                }
                .disabled(value == nil && endDate >= startDate)
            }
        }
        .onAppear {
            valueFieldIsFocused = true
        }
    }
    
    init(sampleType: SampleType<HKQuantitySample>) {
        self.sampleTypeTitle = sampleType.displayTitle
        self.sampleTypeUnit = sampleType.displayUnit
        self.save = { `self` in
            guard let value = self.value else {
                return
            }
            let sample = HKQuantitySample(
                type: sampleType.hkSampleType,
                quantity: HKQuantity(unit: sampleType.displayUnit, doubleValue: value),
                start: self.startDate,
                end: self.endDate
            )
            try await self.healthKit.save(sample)
        }
    }
    
    init(sampleType: CustomHealthSample.SampleType) {
        guard let unit = sampleType.displayUnit else {
            preconditionFailure("Unsupported sample type: \(sampleType.displayTitle)")
        }
        self.sampleTypeTitle = sampleType.displayTitle
        self.sampleTypeUnit = unit
        self.save = { `self` in
            guard let value = self.value else {
                return
            }
            let sample = CustomHealthSample(
                sampleType: sampleType,
                startDate: self.startDate,
                endDate: self.endDate,
                unit: unit,
                value: value
            )
            self.modelContext.insert(sample)
            try self.modelContext.save()
        }
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
