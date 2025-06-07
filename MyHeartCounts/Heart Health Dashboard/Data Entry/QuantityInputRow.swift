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


struct QuantityInputRow: View {
    private let title: String
    @Binding private var value: Double?
    private let unit: HKUnit?
    // Note: using a NumberFormatter() instead of the new `FloatingPointFormatStyle<Double>.number` API,
    // because of https://github.com/swiftlang/swift-foundation/issues/135
    private let formatter = NumberFormatter()
    
    var body: some View {
        HStack {
            Text(title)
            TextField(value: $value, formatter: formatter, prompt: Text("0")) {
                Text(title)
            }
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            if let unit, unit != .count() {
                Text(unit.unitString)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    
    // MARK: Double
    
    init(title: String, value: Binding<Double?>, sampleType: SampleType<HKQuantitySample>?) {
        self.init(title: title, value: value, unit: sampleType?.displayUnit)
    }
    
    init(title: String, value: Binding<Double?>, unit: HKUnit?) {
        self.title = title
        self._value = value
        self.unit = unit
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2 // make this dependent on the context?!
    }
    
    
    // MARK: Int
    
    init(title: String, value: Binding<Int?>, sampleType: SampleType<HKQuantitySample>?) {
        self.init(title: title, value: value, unit: sampleType?.displayUnit)
    }
    
    init(title: String, value: Binding<Int?>, unit: HKUnit?) {
        self.title = title
        self._value = Binding<Double?> {
            value.wrappedValue.flatMap { Double(exactly: $0) }
        } set: { newValue in
            value.wrappedValue = newValue.flatMap { $0.isNaN ? nil : Int($0) }
        }
        self.unit = unit
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
    }
}
