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
    private let title: LocalizedStringResource
    private let limits: Range<Double>?
    @Binding private var value: Double?
    private let unit: HKUnit?
    // Note: using a NumberFormatter() instead of the new `FloatingPointFormatStyle<Double>.number` API,
    // because of https://github.com/swiftlang/swift-foundation/issues/135
    private let formatter = NumberFormatter()
    
    var body: some View {
        VStack {
            HStack {
                Text(title)
                TextField(value: $value, formatter: formatter, prompt: Text("0")) {
                    Text(title)
                }
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .preference(key: ContainsInvalidInputPreferenceKey.self, value: inputIsOutOfLimits)
                if let unit, unit != .count() {
                    Text(unit.unitString)
                        .foregroundStyle(.secondary)
                }
            }
            if inputIsOutOfLimits, let limits {
                let fmt = {
                    // swiftlint:disable:next legacy_objc_type
                    formatter.string(from: NSNumber(value: $0 as Double)) ?? String($0)
                }
                Text("Only values from \(fmt(limits.lowerBound)) to \(fmt(limits.upperBound)) are allowed")
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    private var inputIsOutOfLimits: Bool {
        if let value, let limits, !limits.contains(value) {
            true
        } else {
            false
        }
    }
    
    // MARK: Double
    
    init(title: LocalizedStringResource, value: Binding<Double?>, limits: Range<Double>?, sampleType: SampleType<HKQuantitySample>?) {
        self.init(title: title, value: value, limits: limits, unit: sampleType?.displayUnit)
    }
    
    init(title: LocalizedStringResource, value: Binding<Double?>, limits: Range<Double>?, unit: HKUnit?) {
        self.title = title
        self.limits = limits
        self._value = value
        self.unit = unit
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2 // make this dependent on the context?!
    }
    
    
    // MARK: Int
    
    init(title: LocalizedStringResource, value: Binding<Int?>, limits: Range<Double>?, sampleType: SampleType<HKQuantitySample>?) {
        self.init(title: title, value: value, limits: limits, unit: sampleType?.displayUnit)
    }
    
    init(title: LocalizedStringResource, value: Binding<Int?>, limits: Range<Double>?, unit: HKUnit?) {
        self.title = title
        self.limits = limits
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


extension QuantityInputRow {
    struct ContainsInvalidInputPreferenceKey: PreferenceKey {
        static let defaultValue = false
        
        static func reduce(value: inout Bool, nextValue: () -> Bool) {
            value = value || nextValue()
        }
    }
}


extension View {
    func storeQuantityRowInputsAllValid(in containsInvalidInput: Binding<Bool>) -> some View {
        self.onPreferenceChange(QuantityInputRow.ContainsInvalidInputPreferenceKey.self) {
            containsInvalidInput.wrappedValue = $0
        }
    }
}
