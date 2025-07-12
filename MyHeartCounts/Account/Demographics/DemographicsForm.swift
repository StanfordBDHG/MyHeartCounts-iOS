//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SpeziAccount
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziStudy
import SpeziViews
import SwiftUI


struct DemographicsForm: View {
    @Environment(Account.self)
    private var account: Account?
    
    var body: some View {
        Group {
            if let account, let details = account.details {
                Impl(account: account, details: details)
            } else {
                ContentUnavailableView("Not logged in", systemSymbol: nil)
            }
        }
        .navigationTitle("Demographics")
    }
}


extension DemographicsForm {
    private struct Impl: View {
        @Environment(\.colorScheme)
        private var colorScheme
        
        @Environment(StudyManager.self)
        private var studyManager
        
        @HealthKitCharacteristicQuery(.bloodType)
        private var healthKitBloodType
        
        @HealthKitQuery(.height, timeRange: .ever, limit: 1)
        private var heightSamples
        @HealthKitQuery(.bodyMass, timeRange: .ever, limit: 1)
        private var weightSamples
        
        let account: Account
        let details: AccountDetails
        
        @State private var bloodTypeWasAutoFetchedFromHealthKit = false
        @State private var isShowingEnterHeightSheet = false
        @State private var isShowingEnterWeightSheet = false
        @State private var nhsNumberTextEntry = ""
        
        var body: some View {
            Form {
                dateOfBirthSection
                bodyMeasurementsSection
                raceEthnicitySection
                bloodTypeSection
                comorbiditiesSection
                if studyManager.preferredLocale.region == .germany {
                    nhsNumberSection
                }
            }
        }
        
        @ViewBuilder private var dateOfBirthSection: some View {
            let binding = accountValueBinding(\.dateOfBirth)
                .withDefaultValue(.now)
            Section {
                DatePicker("Date of Birth", selection: binding, displayedComponents: .date)
            }
        }
        
        @ViewBuilder private var raceEthnicitySection: some View {
            let binding = accountValueBinding(\.raceEthnicity)
                .withDefaultValue([])
            Section {
                NavigationLink {
                    RaceEthnicityPicker(selection: binding)
                } label: {
                    LabeledContent("Race / Ethnicity", value: binding.wrappedValue.localizedDisplayTitle)
                }
            }
        }
        
        @ViewBuilder private var bloodTypeSection: some View {
            let binding = accountValueBinding(\.bloodType).withDefaultValue(.notSet)
            Section {
                Picker("Blood Type", selection: binding) {
                    ForEach(HKBloodType.allKnownValues, id: \.self) { bloodType in
                        Text(bloodType.displayTitle)
                    }
                }
                // interesting: if we don't explicitly specify `.pickerStyle(.menu)`, we still get a menu,
                // which has a greyed-out label in the row, but if we add the modifier the label turns blue.
            } footer: {
                if bloodTypeWasAutoFetchedFromHealthKit {
                    Text("The Blood Type value was auto-read from HealthKit")
                }
            }
            .onAppear {
                if binding.wrappedValue == .notSet, let healthKitBloodType, healthKitBloodType != .notSet {
                    binding.wrappedValue = healthKitBloodType
                    bloodTypeWasAutoFetchedFromHealthKit = true
                }
            }
        }
        
        @ViewBuilder private var bodyMeasurementsSection: some View {
            let heightInCMBinding = accountValueBinding(\.heightInCM)
            let weightInKGBinding = accountValueBinding(\.weightInKG)
            let cmUnit = HKUnit.meterUnit(with: .centi)
            let kgUnit = HKUnit.gramUnit(with: .kilo)
            Section { // swiftlint:disable:this closure_body_length
                Button {
                    isShowingEnterHeightSheet = true
                } label: {
                    let sample: QuantitySample? = heightInCMBinding.wrappedValue.map {
                        QuantitySample(id: UUID(), sampleType: .healthKit(.height), unit: cmUnit, value: $0, startDate: .now, endDate: .now)
                    }
                    HStack {
                        Text("Height")
                            .foregroundStyle(colorScheme.textLabelForegroundStyle)
                        Spacer()
                        Text(sample?.valueAndUnitDescription(for: SampleType.height.displayUnit) ?? "—")
                            .foregroundStyle(colorScheme.textLabelForegroundStyle.secondary)
                    }
                    .contentShape(Rectangle())
                }
                Button {
                    isShowingEnterWeightSheet = true
                } label: {
                    let sample: QuantitySample? = weightInKGBinding.wrappedValue.map {
                        QuantitySample(id: UUID(), sampleType: .healthKit(.bodyMass), unit: kgUnit, value: $0, startDate: .now, endDate: .now)
                    }
                    HStack {
                        Text("Weight")
                            .foregroundStyle(colorScheme.textLabelForegroundStyle)
                        Spacer()
                        Text(sample?.valueAndUnitDescription(for: SampleType.bodyMass.displayUnit) ?? "—")
                            .foregroundStyle(colorScheme.textLabelForegroundStyle.secondary)
                    }
                    .contentShape(Rectangle())
                }
                Button {
                    if let heightSample = heightSamples.last {
                        heightInCMBinding.wrappedValue = heightSample.quantity.doubleValue(for: cmUnit)
                    }
                    if let weightSample = weightSamples.last {
                        weightInKGBinding.wrappedValue = weightSample.quantity.doubleValue(for: kgUnit)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Read from HealthKit")
                        Text(
                            """
                            Use this option to auto-fill Height and Weight, by reading the most recent value for each from HealthKit.
                            Alternatively, you can tap the field above to manually enter a value.
                            """
                        )
                        .font(.footnote)
                        .foregroundStyle(colorScheme.textLabelForegroundStyle.secondary)
                    }
                }
            }
            .sheet(isPresented: $isShowingEnterHeightSheet) {
                SaveQuantitySampleView(sampleType: .healthKit(.height)) { sample in
                    heightInCMBinding.wrappedValue = sample.value(as: cmUnit)
                }
            }
            .sheet(isPresented: $isShowingEnterWeightSheet) {
                SaveQuantitySampleView(sampleType: .healthKit(.bodyMass)) { sample in
                    weightInKGBinding.wrappedValue = sample.value(as: kgUnit)
                }
            }
        }
        
        @ViewBuilder private var nhsNumberSection: some View {
            let binding = accountValueBinding(\.nhsNumber).withDefaultValue("")
            Section {
                let title: LocalizedStringResource = "NHS Number (Optional)"
                HStack {
                    Text(title)
                    TextField(text: $nhsNumberTextEntry, prompt: Text("0")) {
                        Text(title)
                    }
                    .multilineTextAlignment(.trailing)
                    .onAppear {
                        nhsNumberTextEntry = binding.wrappedValue
                    }
                    .onChange(of: nhsNumberTextEntry) { _, newValue in
                        binding.wrappedValue = newValue
                    }
                }
            }
        }
        
        @ViewBuilder private var comorbiditiesSection: some View {
            Section {
                LabeledContent("Comorbidities", value: "TODO")
            }
        }
        
        
        private func accountValueBinding<Value: Equatable>(
            _ keyPath: WritableKeyPath<AccountDetails, Value?>
        ) -> Binding<Value?> {
            Binding {
                details[keyPath: keyPath]
            } set: { newValue in
                let oldValue = details[keyPath: keyPath]
                guard oldValue != newValue else {
                    return
                }
                Task {
                    let modifications: AccountModifications
                    if oldValue != nil && newValue == nil {
                        var removedDetails = AccountDetails()
                        removedDetails[keyPath: keyPath] = oldValue
                        modifications = try .init(modifiedDetails: AccountDetails(), removedAccountDetails: removedDetails)
                    } else {
                        var updatedDetails = AccountDetails()
                        updatedDetails[keyPath: keyPath] = newValue
                        modifications = try .init(modifiedDetails: updatedDetails)
                    }
                    do {
                        logger.notice("will update account details")
                        try await account.accountService.updateAccountDetails(modifications)
                        logger.notice("did update account details")
                    } catch {
                        logger.error("Error updating account details: \(error)")
                    }
                }
            }
        }
    }
}


extension Binding {
    func withDefaultValue<Wrapped>(
        _ default: @autoclosure @Sendable @escaping () -> Wrapped
    ) -> Binding<Wrapped> where Value == Wrapped?, Self: Sendable {
        Binding<Wrapped> {
            self.wrappedValue ?? `default`()
        } set: {
            self.wrappedValue = $0
        }
    }
}
