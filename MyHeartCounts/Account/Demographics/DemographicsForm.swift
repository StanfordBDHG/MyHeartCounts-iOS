//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order type_body_length closure_body_length

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


private struct Impl: View {
    // swiftlint:disable attributes
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(HealthKit.self) private var healthKit
    @Environment(StudyManager.self) private var studyManager
    @Environment(AccountFeatureFlags.self) private var accountFeatureFlags
    
    @HealthKitCharacteristicQuery(.bloodType) private var healthKitBloodType
    @HealthKitQuery(.height, timeRange: .ever, limit: 1) private var heightSamples
    @HealthKitQuery(.bodyMass, timeRange: .ever, limit: 1) private var weightSamples
    // swiftlint:enable attributes
    
    let account: Account
    let details: AccountDetails
    
    @State private var viewState: ViewState = .idle
    @State private var regionOverride: Locale.Region?
    @State private var isShowingEnterHeightSheet = false
    @State private var isShowingEnterWeightSheet = false
    @State private var nhsNumberTextEntry = ""
    @State private var isPresentingUKCountyPicker = false
    
    private var region: Locale.Region {
        regionOverride ?? studyManager.preferredLocale.region ?? .unitedStates
    }
    
    private var bloodTypeBinding: Binding<HKBloodType> {
        accountValueBinding(\.bloodType).withDefaultValue(.notSet)
    }
    var heightInCMBinding: Binding<Double?> {
        accountValueBinding(\.heightInCM)
    }
    var weightInKGBinding: Binding<Double?> {
        accountValueBinding(\.weightInKG)
    }
    
    var body: some View {
        Form {
            if accountFeatureFlags.isDebugModeEnabled {
                Section {
                    Picker("Override Region", selection: $regionOverride) {
                        ForEach([Locale.Region?.none, .unitedStates, .unitedKingdom, .germany], id: \.self) { region in
                            if let region {
                                Text(region.localizedName(in: locale, includeEmoji: .front))
                            } else {
                                Text("Disable Override")
                            }
                        }
                    }
                    LabeledContent("Effective Region", value: region.localizedName(in: locale, includeEmoji: .front))
                }
            }
            Section {
                readFromHealthKitButton
            }
            dateOfBirthAndGenderSection
            bodyMeasurementsSection
            raceEthnicitySection
            switch region {
            case .unitedStates:
                usStateRow
                makeIncomeRow(\.householdIncomeUS)
            case .unitedKingdom:
                ukRegionRows
                makeIncomeRow(\.householdIncomeUK)
            default:
                EmptyView()
            }
            bloodTypeSection
            comorbiditiesSection
            if region == .unitedKingdom {
                nhsNumberSection
            }
            Section {
                let binding = accountValueBinding(\.futureStudies).withDefaultValue(false)
                Toggle(isOn: binding) {
                    VStack(alignment: .leading) {
                        Text("Future Studies")
                        Text("May we contact you about future studies that may be of interest to you?")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder private var readFromHealthKitButton: some View {
        AsyncButton(state: $viewState) {
            try await healthKit.askForAuthorization(for: .init(read: [
                HealthKitCharacteristic.bloodType.hkType,
                SampleType.height.hkSampleType, SampleType.bodyMass.hkSampleType
            ]))
            if bloodTypeBinding.wrappedValue == .notSet, let healthKitBloodType {
                bloodTypeBinding.wrappedValue = healthKitBloodType
            }
            if let heightSample = heightSamples.last {
                heightInCMBinding.wrappedValue = heightSample.quantity.doubleValue(for: .meterUnit(with: .centi))
            }
            if let weightSample = weightSamples.last {
                weightInKGBinding.wrappedValue = weightSample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Image(systemSymbol: .heartTextSquare)
                    .accessibilityHidden(true)
                VStack(alignment: .listRowSeparatorLeading) {
                    Text("Read from HealthKit")
                    Text(
                        """
                        Use this option to auto-fill Blood Type, Height and Weight, by reading each from HealthKit, if available.
                        Alternatively, you can also tap the respective fields below to manually enter a value.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(colorScheme.textLabelForegroundStyle.secondary)
                }
            }
        }
    }
    
    @ViewBuilder private var dateOfBirthAndGenderSection: some View {
        let dobBinding = accountValueBinding(\.dateOfBirth).withDefaultValue(.now)
        let genderBinding = accountValueBinding(\.mhcGenderIdentity).withDefaultValue(.preferNotToState)
        let sexAtBirthBinding = accountValueBinding(\.biologicalSexAtBirth).withDefaultValue(.preferNotToState)
        Section {
            DatePicker("Date of Birth", selection: dobBinding, displayedComponents: .date)
            Picker("Gender Identity", selection: genderBinding) {
                ForEach(GenderIdentity.allCases, id: \.self) { option in
                    Text(option.displayTitle)
                }
            }
            Picker("Biological Sex at Birth", selection: sexAtBirthBinding) {
                ForEach(BiologicalSex.allCases, id: \.self) { option in
                    Text(option.displayTitle)
                }
            }
        }
        .onChange(of: genderBinding.wrappedValue) { _, newGender in
            guard sexAtBirthBinding.wrappedValue == .preferNotToState else {
                return
            }
            switch newGender {
            case .male, .transFemale:
                sexAtBirthBinding.wrappedValue = .male
            case .female, .transMale:
                sexAtBirthBinding.wrappedValue = .female
            case .other, .preferNotToState:
                break
            }
        }
    }
    
    @ViewBuilder private var raceEthnicitySection: some View {
        let raceBinding = accountValueBinding(\.raceEthnicity).withDefaultValue([])
        let latinoStatusBinding = accountValueBinding(\.latinoStatus).withDefaultValue(.notSet)
        Section {
            NavigationLink {
                RaceEthnicityPicker(selection: raceBinding)
            } label: {
                LabeledContent("Race / Ethnicity", value: raceBinding.wrappedValue.localizedDisplayTitle)
            }
            if region == .unitedStates {
                Picker("Are you Hispanic/Latino?", selection: latinoStatusBinding) {
                    ForEach(LatinoStatusOption.allOptions, id: \.self) { option in
                        Text(option.displayTitle)
                    }
                }
            }
        }
    }
    
    @ViewBuilder private var bloodTypeSection: some View {
        Section {
            Picker("Blood Type", selection: bloodTypeBinding) {
                ForEach(HKBloodType.allKnownValues, id: \.self) { bloodType in
                    Text(bloodType.displayTitle)
                }
            }
            // interesting: if we don't explicitly specify `.pickerStyle(.menu)`, we still get a menu,
            // which has a greyed-out label in the row, but if we add the modifier the label turns blue.
        }
    }
    
    @ViewBuilder private var bodyMeasurementsSection: some View {
        let cmUnit = HKUnit.meterUnit(with: .centi)
        let kgUnit = HKUnit.gramUnit(with: .kilo)
        Section {
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
        let binding = accountValueBinding(\.comorbidities).withDefaultValue([])
        Section {
            NavigationLink {
                Form {
                    Section {
                        ForEach(Comorbidities.allOptions, id: \.self) { option in
                            Button {
                                binding.wrappedValue.toggleMembership(of: option)
                            } label: {
                                HStack {
                                    Text(option.localizedDisplayTitle)
                                        .foregroundStyle(colorScheme.textLabelForegroundStyle)
                                    Spacer()
                                    if binding.wrappedValue.contains(option) {
                                        Image(systemSymbol: .checkmark)
                                            .fontWeight(.medium)
                                            .accessibilityLabel("Selection Checkmark")
                                    }
                                }
                            }
                        }
                    } footer: {
                        Text("You can select multiple options")
                    }
                }
            } label: {
                LabeledContent("Comorbidities", value: binding.wrappedValue.localizedDisplayTitle)
            }
        }
    }
    
    @ViewBuilder private var usStateRow: some View {
        let binding = accountValueBinding(\.usRegion).withDefaultValue(.notSet)
        NavigationLink {
            USRegionPicker(selection: binding)
        } label: {
            LabeledContent("US State / Territory", value: binding.wrappedValue.name.localizedString())
        }
    }
    
    @ViewBuilder private var ukRegionRows: some View {
        let regionBinding = accountValueBinding(\.ukRegion).withDefaultValue(.notSet)
        let countyBinding = accountValueBinding(\.ukCounty)
        Picker("Region", selection: regionBinding) {
            ForEach(UKRegion.allCases, id: \.self) { region in
                Text(region.displayTitle)
            }
        }
        Button {
            isPresentingUKCountyPicker = true
        } label: {
            HStack {
                Text("County")
                Spacer()
                if let county = countyBinding.wrappedValue {
                    Text(county.displayTitle)
                        .foregroundStyle(.secondary)
                }
                DisclosureIndicator()
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .foregroundStyle(colorScheme.textLabelForegroundStyle)
        }
        .disabled(regionBinding.wrappedValue == .notSet)
        .sheet(isPresented: $isPresentingUKCountyPicker) {
            let items: [UKRegion.County] = switch regionBinding.wrappedValue {
            case .notSet: []
            case .england: UKRegion.County.englishCounties
            case .scotland: UKRegion.County.scottishCounties
            case .wales: UKRegion.County.welshCounties
            case .northernIreland: UKRegion.County.northernIrishCounties
            }
            ListSelectionSheet("Select County", items: items, selection: countyBinding) { county in
                String(localized: county.displayTitle)
            }
        }
    }
    
    @ViewBuilder
    private func makeIncomeRow<HI: HouseholdIncome>(_ keyPath: WritableKeyPath<AccountDetails, HI?>) -> some View {
        let binding = accountValueBinding(keyPath).withDefaultValue(.notSet)
        Picker("Total Household Income", selection: binding) {
            ForEach(HI.allCases, id: \.self) { option in
                Text(option.displayTitle)
            }
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
