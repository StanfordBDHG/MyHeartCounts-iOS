//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order type_body_length closure_body_length file_length

import Foundation
import OSLog
import SFSafeSymbols
import SpeziAccount
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziStudy
import SpeziViews
import SwiftUI


struct DemographicsForm<Footer: View>: View {
    @Environment(Account.self)
    private var account: Account?
    
    private let footer: @MainActor () -> Footer
    
    var body: some View {
        Group {
            if let account, let details = account.details {
                Impl(account: account, details: details, footer: footer())
            } else {
                ContentUnavailableView("Not logged in", systemSymbol: nil)
            }
        }
        .navigationTitle("Demographics")
    }
    
    init(@ViewBuilder footer: @MainActor @escaping () -> Footer = { EmptyView() }) {
        self.footer = footer
    }
}


private struct Impl<Footer: View>: View {
    // swiftlint:disable attributes
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(HealthKit.self) private var healthKit
    @Environment(StudyManager.self) private var studyManager
    @Environment(AccountFeatureFlags.self) private var accountFeatureFlags
    
    @HealthKitCharacteristicQuery(.bloodType) private var healthKitBloodType
    @HealthKitCharacteristicQuery(.dateOfBirth) private var healthKitDateOfBirth
    @HealthKitCharacteristicQuery(.biologicalSex) private var healthKitBiologicalSex
    @HealthKitQuery(.height, timeRange: .ever, limit: 1) private var heightSamples
    @HealthKitQuery(.bodyMass, timeRange: .ever, limit: 1) private var weightSamples
    // swiftlint:enable attributes
    
    let account: Account
    let details: AccountDetails
    let footer: Footer
    
    @State private var viewState: ViewState = .idle
    @State private var regionOverride: Locale.Region?
    @State private var isShowingEnterHeightSheet = false
    @State private var isShowingEnterWeightSheet = false
    @State private var isPresentingUKCountyPicker = false
    
    private var region: Locale.Region {
        regionOverride ?? studyManager.preferredLocale.region ?? .unitedStates
    }
    
    private var dateOfBirthBinding: Binding<Date> {
        accountValueBinding(\.dateOfBirth).withDefaultValue(.now)
    }
    private var bloodTypeBinding: Binding<HKBloodType> {
        accountValueBinding(\.bloodType).withDefaultValue(.notSet)
    }
    private var heightInCMBinding: Binding<Double?> {
        accountValueBinding(\.heightInCM)
    }
    private var weightInKGBinding: Binding<Double?> {
        accountValueBinding(\.weightInKG)
    }
    private var genderBinding: Binding<GenderIdentity> {
        accountValueBinding(\.mhcGenderIdentity).withDefaultValue(.preferNotToState)
    }
    private var sexAtBirthBinding: Binding<BiologicalSex> {
        accountValueBinding(\.biologicalSexAtBirth).withDefaultValue(.preferNotToState)
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
                        Text("Can we contact you about future studies that may be of interest to you?")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            footer
        }
        .accessibilityIdentifier("DemographicsForm")
        .viewStateAlert(state: $viewState)
        .toolbar {
            if ProcessInfo.isBeingUITested {
                testingSupportMenu
            }
        }
        .sheet(isPresented: $isShowingEnterHeightSheet) {
            NavigationStack {
                SaveQuantitySampleView("Enter Height", sampleType: .healthKit(.height)) { sample in
                    heightInCMBinding.wrappedValue = sample.value(as: .meterUnit(with: .centi))
                }
            }
        }
        .sheet(isPresented: $isShowingEnterWeightSheet) {
            NavigationStack {
                SaveQuantitySampleView("Enter Weight", sampleType: .healthKit(.bodyMass)) { sample in
                    weightInKGBinding.wrappedValue = sample.value(as: .gramUnit(with: .kilo))
                }
            }
        }
    }
    
    @ViewBuilder private var readFromHealthKitButton: some View {
        LabeledButton(
            symbol: .heartTextSquare,
            title: "Read from Health App",
            subtitle: """
                Use this option to auto-fill Blood Type, Height, Weight, Date of Birth, and Biological Sex, by reading each from the Health app, if available.
                Alternatively, you can also tap the respective fields below to manually enter a value, or to override the value read from the Health app.
                """,
            state: $viewState
        ) {
            // this likely isn't necessary
            try await healthKit.askForAuthorization(for: .init(read: [
                HealthKitCharacteristic.bloodType.hkType,
                HealthKitCharacteristic.biologicalSex.hkType,
                SampleType.height.hkSampleType, SampleType.bodyMass.hkSampleType
            ]))
            if calendar.isDateInToday(dateOfBirthBinding.wrappedValue), let healthKitDateOfBirth {
                // we set the time to noon to try to work around time zone issues
                dateOfBirthBinding.wrappedValue = calendar.makeNoon(healthKitDateOfBirth)
            }
            if bloodTypeBinding.wrappedValue == .notSet, let healthKitBloodType {
                bloodTypeBinding.wrappedValue = healthKitBloodType
            }
            if let heightSample = heightSamples.last {
                heightInCMBinding.wrappedValue = heightSample.quantity.doubleValue(for: .meterUnit(with: .centi))
            }
            if let weightSample = weightSamples.last {
                weightInKGBinding.wrappedValue = weightSample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            }
            if sexAtBirthBinding.wrappedValue == .preferNotToState, let healthKitBiologicalSex {
                sexAtBirthBinding.wrappedValue = switch healthKitBiologicalSex {
                case .female: .female
                case .male: .male
                case .other: .preferNotToState // not perfect but the best we can do
                case .notSet: .preferNotToState
                @unknown default: .preferNotToState
                }
            }
        }
        .accessibilityLabel("Read from Health App")
    }
    
    @ViewBuilder private var dateOfBirthAndGenderSection: some View {
        Section {
            DatePicker(
                "Date of Birth",
                selection: Binding<Date> {
                    calendar.makeNoon(dateOfBirthBinding.wrappedValue)
                } set: { newValue in
                    dateOfBirthBinding.wrappedValue = calendar.makeNoon(newValue)
                },
                displayedComponents: .date
            )
            .accessibilityLabel("Date of Birth")
            .accessibilityValue(dateOfBirthBinding.wrappedValue.formatted(.iso8601.year().month().day()))
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
        .onChange(of: sexAtBirthBinding.wrappedValue) { _, newSexAtBirth in
            guard genderBinding.wrappedValue == .preferNotToState else {
                return
            }
            switch newSexAtBirth {
            case .male:
                genderBinding.wrappedValue = .male
            case .female:
                genderBinding.wrappedValue = .female
            case .preferNotToState, .intersex:
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
        let makeSample = { (sampleType: SampleType<HKQuantitySample>, value: Double, unit: HKUnit) -> QuantitySample in
            let now = Date.now
            return QuantitySample(id: UUID(), sampleType: .healthKit(sampleType), unit: unit, value: value, startDate: now, endDate: now)
        }
        Section {
            Button {
                isShowingEnterHeightSheet = true
            } label: {
                let sample: QuantitySample? = heightInCMBinding.wrappedValue.map {
                    makeSample(.height, $0, .meterUnit(with: .centi))
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
                    makeSample(.bodyMass, $0, .gramUnit(with: .kilo))
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
    }
    
    @ViewBuilder private var nhsNumberSection: some View {
        let binding = accountValueBinding(\.nhsNumber).withDefaultValue(NHSNumber(unchecked: ""))
        Section {
            NHSNumberTextField(value: binding)
        } header: {
            Text("NHS Number")
        } footer: {
            let url = try! URL("https://www.nhs.uk/nhs-services/online-services/find-nhs-number/", strategy: .url) // swiftlint:disable:this force_try
            Link("Find your NHS Number", destination: url)
                .font(.footnote)
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


extension Impl {
    @ToolbarContentBuilder private var testingSupportMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                AsyncButton("Add Height & Weight Samples", state: $viewState) {
                    let samples = [
                        HKQuantitySample(
                            type: SampleType.height.hkSampleType,
                            quantity: HKQuantity(unit: .meterUnit(with: .centi), doubleValue: 186),
                            start: .now,
                            end: .now
                        ),
                        HKQuantitySample(
                            type: SampleType.bodyMass.hkSampleType,
                            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 70),
                            start: .now,
                            end: .now
                        )
                    ]
                    try await healthKit.save(samples)
                }
            } label: {
                Text("Testing Support")
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
