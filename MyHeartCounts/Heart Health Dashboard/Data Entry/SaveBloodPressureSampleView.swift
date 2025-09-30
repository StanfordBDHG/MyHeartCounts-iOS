//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SFSafeSymbols
import SpeziHealthKit
import SpeziViews
import SwiftUI


struct SaveBloodPressureSampleView: View {
    private enum Field: Int, Hashable, CaseIterable, Comparable {
        case systolic
        case diastolic
        
        var prev: Self? {
            Self.allCases.last { $0 < self }
        }
        
        var next: Self? {
            Self.allCases.first { $0 > self }
        }
        
        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    @Environment(HealthKit.self)
    private var healthKit
    @Environment(\.dismiss)
    private var dismiss
    
    @FocusState private var focusedField: Field?
    @State private var viewState: ViewState = .idle
    @State private var date: Date = .now
    @State private var systolic: Int?
    @State private var diastolic: Int?
    
    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $date)
                makeRow(for: $systolic, sampleType: .bloodPressureSystolic)
                    .focused($focusedField, equals: .systolic)
                makeRow(for: $diastolic, sampleType: .bloodPressureDiastolic)
                    .focused($focusedField, equals: .diastolic)
            }
        }
        .navigationTitle("Enter Blood Pressure")
        .viewStateAlert(state: $viewState)
        .toolbar {
            navigationToobarItems
            focusToolbarItems
        }
        .onAppear {
            guard focusedField == nil else {
                return
            }
            if systolic != nil && diastolic == nil {
                focusedField = .diastolic
            } else {
                focusedField = .systolic
            }
        }
    }
    
    
    @ToolbarContentBuilder private var navigationToobarItems: some ToolbarContent {
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
    
    @ToolbarContentBuilder private var focusToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .keyboard) {
            HStack {
                Spacer()
                Button {
                    focusedField = focusedField?.prev
                } label: {
                    Image(systemSymbol: .chevronLeft)
                        .accessibilityLabel("Go to previous field")
                }
                .disabled(focusedField?.prev == nil)
                Button {
                    focusedField = focusedField?.next
                } label: {
                    Image(systemSymbol: .chevronRight)
                        .accessibilityLabel("Go to next field")
                }
                .disabled(focusedField?.next == nil)
            }
        }
    }
    
    private func makeRow(for value: Binding<Int?>, sampleType: SampleType<HKQuantitySample>) -> some View {
        QuantityInputRow(title: sampleType.mhcDisplayTitle, value: value, sampleType: sampleType)
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
