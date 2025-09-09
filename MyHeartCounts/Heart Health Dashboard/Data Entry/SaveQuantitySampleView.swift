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
    
    @Environment(MyHeartCountsStandard.self)
    private var standard
    
    private let title: LocalizedStringKey
    private let sampleType: MHCQuantitySampleType
    private let completionHandler: (@MainActor (QuantitySample) -> Void)?
    @State private var date: Date = .now
    @State private var value: Double?
    @State private var viewState: ViewState = .idle
    @FocusState private var valueFieldIsFocused: Bool
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Sample Type", value: sampleType.displayTitle)
                DatePicker("Date", selection: $date)
                QuantityInputRow(title: "Value", value: $value, unit: sampleType.displayUnit)
                    .focused($valueFieldIsFocused)
            }
        }
        .navigationTitle(title)
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
                .disabled(value == nil)
            }
        }
        .onAppear {
            valueFieldIsFocused = true
        }
    }
    
    init(
        _ title: LocalizedStringKey = "Add Sample", // swiftlint:disable:this function_default_parameter_at_end
        sampleType: MHCQuantitySampleType,
        completionHandler: (@MainActor (QuantitySample) -> Void)? = nil
    ) {
        self.title = title
        self.sampleType = sampleType
        self.completionHandler = completionHandler
    }
    
    
    private func save() async throws {
        guard let value = self.value else {
            return
        }
        switch sampleType {
        case .healthKit(let sampleType):
            let sample = HKQuantitySample(
                type: sampleType.hkSampleType,
                quantity: HKQuantity(unit: sampleType.displayUnit, doubleValue: value),
                start: self.date,
                end: self.date
            )
            do {
                try await self.healthKit.save(sample)
                completionHandler?(.init(sample))
            } catch let error as HKError where error.code == .errorAuthorizationDenied {
                throw CustomError.missingHealthKitPermissions(sampleType)
            } catch {
                throw error
            }
        case .custom(let sampleType):
            let sample = QuantitySample(
                id: UUID(),
                sampleType: .custom(sampleType),
                unit: sampleType.displayUnit,
                value: value,
                startDate: self.date,
                endDate: self.date
            )
            try await self.standard.uploadHealthObservation(sample)
            completionHandler?(sample)
        }
    }
}


extension SaveQuantitySampleView {
    private enum CustomError: Error, LocalizedError {
        case missingHealthKitPermissions(SampleType<HKQuantitySample>)
        
        var errorDescription: String? {
            switch self {
            case .missingHealthKitPermissions(let sampleType):
                "Unable to save \(sampleType.displayTitle)"
            }
        }
        
        var failureReason: String? {
            switch self {
            case .missingHealthKitPermissions:
                "You haven't granted My Heart Counts permission to add data to HealthKit"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .missingHealthKitPermissions:
                "You can change this in the iOS Settings app, under Privacy & Security → Health → My Heart Counts"
            }
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
