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
import SwiftUI


struct HeightInputRow: View {
    private enum InputUnit {
        case centimeters
        case feetAndInches
    }
    
    private let title: LocalizedStringResource
    @Binding private var quantity: HKQuantity?
    private let inputUnit: InputUnit
    @State private var showPicker = false
    
    var body: some View {
        switch inputUnit {
        case .centimeters:
            let cmUnit = HKUnit.meterUnit(with: .centi)
            let binding = Binding<Double?> {
                quantity?.doubleValue(for: cmUnit)
            } set: { newValue in
                if let newValue {
                    quantity = HKQuantity(unit: cmUnit, doubleValue: newValue)
                } else {
                    quantity = nil
                }
            }
            QuantityInputRow(
                title: title,
                value: binding,
                limits: MHCQuantitySampleType.healthKit(.height).inputLimits(in: cmUnit),
                unit: cmUnit
            )
        case .feetAndInches:
            // no need to perform input validation here; that's handled via the wheel-styled picker
            HStack {
                Text(title)
                Spacer()
                // maybe give it a rounded-rect background, like what the Health app does?
                if let (feet, inches) = quantity?.valuesForFeetAndInches() {
                    Text("\(feet)‘ \(Int(inches))“")
                } else {
                    Text("—")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // animate this (not easy, apparently...)
                showPicker.toggle()
            }
            if showPicker {
                FootPicker(quantity: $quantity, limits: .init(feet: 3..<9, inches: 0..<12))
            }
        }
    }
    
    
    init(title: LocalizedStringResource, quantity: Binding<HKQuantity?>, preferredUnit: HKUnit) {
        self.title = title
        self._quantity = quantity
        self.inputUnit = preferredUnit == .foot() ? .feetAndInches : .centimeters
    }
}


extension HeightInputRow {
    private struct FootPicker: View {
        struct Limits {
            let feet: Range<Int>
            let inches: Range<Int>
        }
        
        private let limits: Limits
        @State private var feet: Int
        @State private var inches: Int
        @Binding var quantity: HKQuantity?
        
        var body: some View {
            HStack(spacing: 0) {
                Picker("", selection: $feet) {
                    ForEach(Array(limits.feet), id: \.self) { value in
                        Text("\(value) ft")
                    }
                }
                Picker("", selection: $inches) {
                    ForEach(Array(limits.inches), id: \.self) { value in
                        Text("\(value) in")
                    }
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: feet, updateQuantity)
            .onChange(of: inches, updateQuantity)
            .onAppear { updateQuantity() }
        }
        
        init(quantity: Binding<HKQuantity?>, limits: Limits) {
            self.limits = limits
            _quantity = quantity
            if let (feet, inches) = quantity.wrappedValue?.valuesForFeetAndInches() {
                _feet = .init(initialValue: feet)
                _inches = .init(initialValue: Int(inches))
            } else {
                _feet = .init(initialValue: 5)
                _inches = .init(initialValue: 4)
            }
        }
        
        private func updateQuantity() {
            let total = Measurement(value: Double(feet), unit: UnitLength.feet) + Measurement(value: Double(inches), unit: .inches)
            quantity = HKQuantity(unit: .meter(), doubleValue: total.converted(to: .meters).value)
        }
    }
}
