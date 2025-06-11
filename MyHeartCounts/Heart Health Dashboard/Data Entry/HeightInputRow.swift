//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SwiftUI


struct HeightInputRow: View {
    private enum InputUnit {
        case centimeters
        case feetAndInches
    }
    
    private let title: String
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
            QuantityInputRow(title: title, value: binding, unit: cmUnit)
        case .feetAndInches:
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
                FootPicker(quantity: $quantity)
            }
        }
    }
    
    
    init(title: String, quantity: Binding<HKQuantity?>, preferredUnit: HKUnit) {
        self.title = title
        self._quantity = quantity
        self.inputUnit = preferredUnit == .foot() ? .feetAndInches : .centimeters
    }
}


extension HeightInputRow {
    private struct FootPicker: View {
        @State private var feet: Int
        @State private var inches: Int
        @Binding var quantity: HKQuantity?
        
        var body: some View {
            HStack(spacing: 0) {
                Picker("", selection: $feet) {
                    ForEach(0..<10) { value in
                        Text("\(value) ft")
                    }
                }.pickerStyle(.wheel)
                Picker("", selection: $inches) {
                    ForEach(0..<12) { value in
                        Text("\(value) in")
                    }
                }.pickerStyle(.wheel)
            }
            .onChange(of: feet, updateQuantity)
            .onChange(of: inches, updateQuantity)
            .onAppear { updateQuantity() }
        }
        
        init(quantity: Binding<HKQuantity?>) {
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
