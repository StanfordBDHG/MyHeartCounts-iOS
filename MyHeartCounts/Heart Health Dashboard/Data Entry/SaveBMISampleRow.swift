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


struct SaveBMISampleView: View {
    private enum InputMode: Hashable, CaseIterable {
        case bmiDirect
        case weightAndHeight
        
        var displayTitle: String {
            switch self {
            case .bmiDirect: "BMI"
            case .weightAndHeight: "Weight and Height"
            }
        }
    }
    
    @Environment(HealthKit.self)
    private var healthKit
    @Environment(\.dismiss)
    private var dismiss
    
    private let bmiSampleType = SampleType.bodyMassIndex
    private let weightSampleType = SampleType.bodyMass
    private let heightSampleType = SampleType.height
    
    @State private var viewState: ViewState = .idle
    @State private var inputMode: InputMode = .weightAndHeight
    @State private var date: Date = .now
    @State private var bmi: Double?
    @State private var weight: Double?
    @State private var height: Double?
    
    var body: some View {
        Form {
            Section {
                Picker("Input Mode", selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.displayTitle)
                    }
                }
                .pickerStyle(.segmented)
                .labelsVisibility(.visible)
            }
            Section {
                DatePicker("Date", selection: $date)
                switch inputMode {
                case .bmiDirect:
                    QuantityInputRow(title: "Body Mass Index", value: $bmi, sampleType: bmiSampleType)
                case .weightAndHeight:
                    QuantityInputRow(title: "Weight", value: $weight, sampleType: weightSampleType)
                    HeightInputRow(
                        title: "Height",
                        quantity: Binding<HKQuantity?> {
                            height.map { HKQuantity(unit: heightSampleType.displayUnit, doubleValue: $0) }
                        } set: { newValue in
                            height = newValue?.doubleValue(for: heightSampleType.displayUnit)
                        },
                        preferredUnit: heightSampleType.displayUnit
                    )
                }
            }
        }
        .navigationTitle("Enter BMI")
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
                .disabled(bmi == nil)
            }
        }
        .onChange(of: weight, updateBMI)
        .onChange(of: height, updateBMI)
    }
    
    private func updateBMI() {
        guard let weight, let height else {
            return
        }
        // we need to go the extra round through HKQuantity in case weight and height are non-metric
        let weightQuantity = HKQuantity(unit: weightSampleType.displayUnit, doubleValue: weight)
        let heightQuantity = HKQuantity(unit: heightSampleType.displayUnit, doubleValue: height)
        bmi = weightQuantity.doubleValue(for: .gramUnit(with: .kilo)) / heightQuantity.doubleValue(for: .meter())
    }
    
    private func save() async throws {
        guard let bmi else {
            return
        }
        var samples: [HKQuantitySample] = [
            HKQuantitySample(
                type: bmiSampleType.hkSampleType,
                quantity: HKQuantity(unit: bmiSampleType.displayUnit, doubleValue: bmi),
                start: date,
                end: date
            )
        ]
        if let height {
            samples.append(HKQuantitySample(
                type: SampleType.height.hkSampleType,
                quantity: HKQuantity(unit: SampleType.height.displayUnit, doubleValue: height),
                start: date,
                end: date
            ))
        }
        if let weight {
            samples.append(HKQuantitySample(
                type: SampleType.bodyMass.hkSampleType,
                quantity: HKQuantity(unit: SampleType.bodyMass.displayUnit, doubleValue: weight),
                start: date,
                end: date
            ))
        }
        try await healthKit.save(samples)
    }
}
