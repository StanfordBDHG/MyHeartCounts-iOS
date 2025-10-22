//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// _swfiftlint:disable file_types_order type_body_length closure_body_length file_length all
// swiftlint:disable file_types_order attributes file_length discouraged_optional_boolean

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


// MARK: DemographicsForm

struct DemographicsForm<Footer: View>: View {
    @Environment(Account.self)
    private var account
    
    @State private var data = DemographicsData(details: .init())
    @Binding private var isComplete: Bool
    
    private let footer: @MainActor () -> Footer
    
    var body: some View {
        Group {
            if let details = account.details {
                Impl(account: account, details: details, isComplete: $isComplete, footer: footer)
                    .environment(data)
            } else {
                ContentUnavailableView("Not logged in", systemSymbol: nil)
            }
        }
        .navigationTitle("Demographics")
        .onAppear {
            if let details = account.details {
                data = .init(details: details)
            }
        }
        .onDisappear {
            Task {
                try await data.write(to: account)
            }
        }
    }
    
    init(
        isComplete: Binding<Bool> = .constant(true),
        @ViewBuilder footer: @MainActor @escaping () -> Footer = { EmptyView() }
    ) {
        self._isComplete = isComplete
        self.footer = footer
    }
}


// MARK: DemographicsData

@Observable
@MainActor
private final class DemographicsData {
    private let initialDetails: AccountDetails
    var dateOfBirth: Date?
    var genderIdentity: GenderIdentity? {
        didSet {
            guard let newGender = genderIdentity, sexAtBirth == nil else {
                return
            }
            switch newGender {
            case .male, .transFemale:
                sexAtBirth = .male
            case .female, .transMale:
                sexAtBirth = .female
            case .other, .preferNotToState:
                break
            }
        }
    }
    var sexAtBirth: BiologicalSex? {
        didSet {
            guard let newSex = sexAtBirth, genderIdentity == nil else {
                return
            }
            switch newSex {
            case .male:
                genderIdentity = .male
            case .female:
                genderIdentity = .female
            case .preferNotToState, .intersex:
                break
            }
        }
    }
    var height: HKQuantity?
    var weight: HKQuantity?
    var raceEthnicity: RaceEthnicity?
    var latinoStatus: LatinoStatusOption?
    var bloodType: HKBloodType?
    var comorbidities: Comorbidities?
    var usRegion: USRegion?
    var ukRegion: UKRegion?
    var usHouseholdIncome: HouseholdIncomeUS?
    var ukHouseholdIncome: HouseholdIncomeUK?
    var nhsNumber: NHSNumber?
    var futureStudiesOptIn: Bool?
    
    init(details: AccountDetails) {
        initialDetails = details
        dateOfBirth = details.dateOfBirth
        genderIdentity = details.mhcGenderIdentity
        sexAtBirth = details.biologicalSexAtBirth
        height = details.heightInCM.map { HKQuantity(unit: .meterUnit(with: .centi), doubleValue: $0) }
        weight = details.weightInKG.map { HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: $0) }
        raceEthnicity = details.raceEthnicity
        latinoStatus = details.latinoStatus
        bloodType = details.bloodType
        comorbidities = details.comorbidities
        usRegion = details.usRegion
        ukRegion = details.ukRegion
        usHouseholdIncome = details.householdIncomeUS
        ukHouseholdIncome = details.householdIncomeUK
        nhsNumber = details.nhsNumber
        futureStudiesOptIn = details.futureStudies
    }
    
    func write(to account: Account) async throws {
        var updated = AccountDetails()
        var removed = AccountDetails()
        func write<T: Equatable>(_ newValue: T?, to detailsKeyPath: WritableKeyPath<AccountDetails, T?>) {
            let oldValue = initialDetails[keyPath: detailsKeyPath]
            switch (oldValue, newValue) {
            case (.none, .none):
                break
            case (.some(let oldValue), .none):
                removed[keyPath: detailsKeyPath] = oldValue
            case let (.some(oldValue), .some(newValue)):
                if oldValue != newValue {
                    fallthrough
                }
            case (_, .some(let newValue)):
                updated[keyPath: detailsKeyPath] = newValue
            }
        }
        func write<T, U: Equatable>(
            _ newValue: T?,
            to detailsKeyPath: WritableKeyPath<AccountDetails, U?>,
            transform: (T) -> U
        ) {
            write(newValue.map(transform), to: detailsKeyPath)
        }
        write(dateOfBirth, to: \.dateOfBirth)
        write(genderIdentity, to: \.mhcGenderIdentity)
        write(sexAtBirth, to: \.biologicalSexAtBirth)
        write(height, to: \.heightInCM) {
            $0.doubleValue(for: .meterUnit(with: .centi))
        }
        write(weight, to: \.weightInKG) {
            $0.doubleValue(for: .gramUnit(with: .kilo))
        }
        write(raceEthnicity, to: \.raceEthnicity)
        write(latinoStatus, to: \.latinoStatus)
        write(bloodType, to: \.bloodType)
        write(comorbidities, to: \.comorbidities)
        write(usRegion, to: \.usRegion)
        write(ukRegion, to: \.ukRegion)
        write(usHouseholdIncome, to: \.householdIncomeUS)
        write(ukHouseholdIncome, to: \.householdIncomeUK)
        write(nhsNumber, to: \.nhsNumber)
        write(futureStudiesOptIn, to: \.futureStudies)
        let modifications = try AccountModifications(modifiedDetails: updated, removedAccountDetails: removed)
        try await account.accountService.updateAccountDetails(modifications)
    }
}


// MARK: Form Implementation

private struct Impl<Footer: View>: View {
    @Environment(\.calendar) private var cal
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(HealthKit.self) private var healthKit
    @Environment(StudyManager.self) private var studyManager
    
    var account: Account
    let details: AccountDetails
    @Binding var isComplete: Bool
    let footer: @MainActor () -> Footer
    
    @DebugModeEnabled private var debugModeEnabled
    
    @State private var viewState: ViewState = .idle
    @State private var regionOverride: Locale.Region?
    
    private var region: Locale.Region {
        regionOverride ?? studyManager.preferredLocale.region ?? .unitedStates
    }
    
    var body: some View {
        Form { // swiftlint:disable:this closure_body_length
            if debugModeEnabled {
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
                ReadFromHealthKitButton(viewState: $viewState)
            }
            Section {
                DemographicsComponent(\.dateOfBirth) { date in
                    cal.isDateInToday(date)
                } content: { binding, isEmpty in
                    let binding = binding.withDefault(.now)
                    DatePicker(
                        "Date of Birth",
                        selection: Binding<Date> {
                            cal.makeNoon(binding.wrappedValue)
                        } set: { newValue in
                            binding.wrappedValue = cal.makeNoon(newValue)
                        },
                        displayedComponents: .date
                    )
                    .accessibilityLabel("Date of Birth")
                    .accessibilityValue(binding.wrappedValue.formatted(.iso8601.year().month().day()))
                    .tint(isEmpty ? .red : nil)
                }
                DemographicsComponent(\.genderIdentity, noSelectionValue: nil) { binding, _ in
                    DemographicsPicker("Gender Identity", selection: binding, optionTitle: \.displayTitle)
                }
                DemographicsComponent(\.sexAtBirth, noSelectionValue: nil) { binding, _ in
                    DemographicsPicker("Biological Sex at Birth", selection: binding, optionTitle: \.displayTitle)
                }
                DemographicsComponent(\.bloodType, noSelectionValue: nil) { binding, _ in
                    DemographicsPicker("Blood Type", selection: binding, allOptions: HKBloodType.allKnownValues, optionTitle: \.displayTitle)
                }
            }
            Section {
                BodyMeasurementRow(descriptor: .height)
                BodyMeasurementRow(descriptor: .weight)
            }
            Section {
                DemographicsComponent(\.raceEthnicity, noSelectionValue: nil, []) { binding, isEmpty in
                    let binding = binding.withDefault([])
                    NavigationLink {
                        RaceEthnicityPicker(selection: binding)
                    } label: {
                        HStack {
                            Text("Race / Ethnicity")
                            Spacer()
                            Text(binding.wrappedValue.localizedDisplayTitle)
                                .foregroundStyle(isEmpty ? .red : .secondary)
                        }
                    }
                }
                if region == .unitedStates {
                    DemographicsComponent(\.latinoStatus, noSelectionValue: nil, .notSet) { binding, _ in
                        makeLatinoStatusRow(binding.withDefault(.notSet))
                    }
                }
            }
            Section {
                DemographicsComponent(\.comorbidities, noSelectionValue: nil) { binding, _ in
                    NavigationLink {
                        ComorbiditiesPicker(selection: binding.withDefault(Comorbidities()))
                    } label: {
                        if let comorbidities = binding.wrappedValue {
                            NavigationLinkLabel("Comorbidities", isEmpty: false, value: "\(comorbidities.count) selected")
                        } else {
                            NavigationLinkLabel("Comorbidities", isEmpty: true, value: "Not Set")
                        }
                    }
                }
            }
            Section {
                switch region {
                case .unitedStates:
                    usStateRow
                    DemographicsComponent(\.usHouseholdIncome, noSelectionValue: nil) { binding, _ in
                        makeIncomeRow(binding.withDefault(.notSet))
                    }
                case .unitedKingdom:
                    ukRegionRow
                    DemographicsComponent(\.ukHouseholdIncome, noSelectionValue: nil) { binding, _ in
                        makeIncomeRow(binding.withDefault(.notSet))
                    }
                default:
                    EmptyView()
                }
            }
            if region == .unitedKingdom {
                nhsNumberSection
            }
            Section {
                DemographicsComponent(\.futureStudiesOptIn, noSelectionValue: nil) { binding, _ in
                    Toggle(isOn: binding.withDefault(false)) {
                        VStack(alignment: .leading) {
                            Text("Future Studies")
                            Text("Can we contact you about future studies that may be of interest to you?")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            footer()
        }
        .viewStateAlert(state: $viewState)
        .toolbar {
            if ProcessInfo.isBeingUITested {
                testingSupportMenu
            }
        }
        .onPreferenceChange(EntryMissingValuePreferenceKey.self) { isIncomplete in
            Task { @MainActor in
                self.isComplete = !isIncomplete
            }
        }
    }
    
    @ViewBuilder private var usStateRow: some View {
        DemographicsComponent(\.usRegion, noSelectionValue: nil) { binding, isEmpty in
            NavigationLink {
                USRegionPicker(selection: binding)
            } label: {
                NavigationLinkLabel(
                    "US State / Territory",
                    isEmpty: isEmpty,
                    value: (binding.wrappedValue?.abbreviation).map { "\($0)" } ?? "No Selection"
                )
            }
        }
    }
    
    @ViewBuilder private var ukRegionRow: some View {
        DemographicsComponent(\.ukRegion, noSelectionValue: nil) { binding, isEmpty in
            NavigationLink {
                UKRegionPicker(selection: binding)
            } label: {
                NavigationLinkLabel(
                    "UK Region",
                    isEmpty: isEmpty,
                    value: binding.wrappedValue?.displayTitle ?? "Not Set"
                )
            }
        }
    }
    
    @ViewBuilder private var nhsNumberSection: some View {
        DemographicsComponent(\.nhsNumber, noSelectionValue: nil) { binding, _ in
            let binding = binding.withDefault(NHSNumber(unchecked: ""))
            Section {
                NHSNumberTextField(value: binding)
            } header: {
                Text("NHS Number")
            } footer: {
                Link("Find your NHS Number", destination: "https://www.nhs.uk/nhs-services/online-services/find-nhs-number/")
                    .font(.footnote)
                    .tint(.blue)
            }
        }
    }
    
    @ViewBuilder
    private func makeIncomeRow<HI: HouseholdIncome>(_ binding: Binding<HI>) -> some View {
        let title: LocalizedStringResource = "Total Household Income"
        NavigationLink {
            DemographicsSingleSelectionPicker(selection: binding)
                .navigationTitle(title)
        } label: {
            NavigationLinkLabel(
                title,
                isEmpty: binding.wrappedValue == .notSet,
                value: binding.wrappedValue.displayTitle
            )
        }
    }
    
    @ViewBuilder
    private func makeLatinoStatusRow(_ binding: Binding<LatinoStatusOption>) -> some View {
        let title: LocalizedStringResource = "Are you Hispanic/Latino?"
        NavigationLink {
            DemographicsSingleSelectionPicker(selection: binding)
                .navigationTitle(title)
        } label: {
            NavigationLinkLabel(
                title,
                isEmpty: binding.wrappedValue == .notSet,
                value: binding.wrappedValue.displayTitle
            )
        }
    }
}


extension Impl {
    private struct ReadFromHealthKitButton: View {
        @Environment(\.calendar) private var cal
        @Environment(HealthKit.self) private var healthKit
        @Environment(DemographicsData.self) private var data
        @HealthKitCharacteristicQuery(.bloodType) private var healthKitBloodType
        @HealthKitCharacteristicQuery(.dateOfBirth) private var healthKitDateOfBirth
        @HealthKitCharacteristicQuery(.biologicalSex) private var healthKitBiologicalSex
        @HealthKitQuery(.height, timeRange: .ever, limit: 1) private var heightSamples
        @HealthKitQuery(.bodyMass, timeRange: .ever, limit: 1) private var weightSamples
        
        @Binding var viewState: ViewState
        
        var body: some View {
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
                    HealthKitCharacteristic.dateOfBirth.hkType,
                    HealthKitCharacteristic.bloodType.hkType,
                    HealthKitCharacteristic.biologicalSex.hkType,
                    SampleType.height.hkSampleType, SampleType.bodyMass.hkSampleType
                ]))
                if cal.isDateInToday(data.dateOfBirth ?? .now), let healthKitDateOfBirth {
                    // we set the time to noon to try to work around time zone issues
                    data.dateOfBirth = cal.makeNoon(healthKitDateOfBirth)
                }
                if data.bloodType == nil, let healthKitBloodType {
                    data.bloodType = healthKitBloodType
                }
                if let heightSample = heightSamples.last {
                    data.height = heightSample.quantity
                }
                if let weightSample = weightSamples.last {
                    data.weight = weightSample.quantity
                }
                if data.sexAtBirth == nil, let healthKitBiologicalSex {
                    data.sexAtBirth = switch healthKitBiologicalSex {
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
    }
}


extension Impl {
    /// A label for use in a `NavigationLink`; automatically adjusts its value's text color based on the presence/absence of a value.
    ///
    /// Intended for use in the ``DemographicsForm``, to highlight missing answers.
    private struct NavigationLinkLabel: View {
        private let title: LocalizedStringResource
        private let isEmpty: Bool
        private let value: LocalizedStringResource
        
        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(isEmpty ? .red : .secondary)
            }
        }
        
        init(_ title: LocalizedStringResource, isEmpty: Bool, value: LocalizedStringResource) {
            self.title = title
            self.isEmpty = isEmpty
            self.value = value
        }
    }
}


extension Impl {
    /// A Form row view for a quantity-based body measurement, e.g. height or weight.
    private struct BodyMeasurementRow: View {
        @MainActor
        struct BodyMeasurementDescriptor: Identifiable {
            static var height: Self { Self(sampleType: .healthKit(.height), keyPath: \.height) }
            static var weight: Self { Self(sampleType: .healthKit(.bodyMass), keyPath: \.weight) }
            
            nonisolated let sampleType: MHCQuantitySampleType
            let keyPath: ReferenceWritableKeyPath<DemographicsData, HKQuantity?>
            nonisolated var id: some Hashable { sampleType }
        }
        
        @Environment(\.colorScheme) private var colorScheme
        @Environment(DemographicsData.self) private var data
        
        let descriptor: BodyMeasurementDescriptor
        @State var isShowingDataEntry = false
        
        var body: some View {
            let sampleType = descriptor.sampleType
            Button {
                isShowingDataEntry = true
            } label: {
                HStack {
                    Text(sampleType.displayTitle)
                        .foregroundStyle(colorScheme.textLabelForegroundStyle)
                    Spacer()
                    let sample = data[keyPath: descriptor.keyPath].flatMap { quantity in
                        QuantitySample(id: UUID(), sampleType: descriptor.sampleType, quantity: quantity, startDate: .now, endDate: .now)
                    }
                    Text(sample?.valueAndUnitDescription(for: sampleType.displayUnit) ?? "—")
                        .foregroundStyle(sample == nil ? .red : .secondary)
                }
                .contentShape(Rectangle())
            }
            .sheet(isPresented: $isShowingDataEntry) {
                NavigationStack {
                    SaveQuantitySampleView(sampleType: sampleType) { sample in
                        data[keyPath: descriptor.keyPath] = HKQuantity(unit: sample.unit, doubleValue: sample.value)
                    }
                }
            }
        }
    }
}


extension Impl {
    /// A `Menu`-styled `Picker` intended for use in the demographics form.
    private struct DemographicsPicker<Value: Hashable>: View {
        private let title: LocalizedStringResource
        @Binding private var selection: Value?
        private let allOptions: [Value]
        private let optionTitle: (Value) -> LocalizedStringResource
        
        var body: some View {
            Picker(title, selection: $selection) {
                Text("—")
                    .tag(Value?.none)
                    .selectionDisabled()
                Divider()
                ForEach(allOptions, id: \.self) { option in
                    Text(optionTitle(option))
                        .tag(Value?.some(option))
                }
            }
            .pickerStyle(.menu)
            .tint(selection == nil ? .red : .secondary)
        }
        
        init(
            _ title: LocalizedStringResource,
            selection: Binding<Value?>,
            allOptions: [Value],
            optionTitle: @escaping (Value) -> LocalizedStringResource
        ) {
            self.title = title
            self._selection = selection
            self.allOptions = allOptions
            self.optionTitle = optionTitle
        }
        
        init(
            _ title: LocalizedStringResource,
            selection: Binding<Value?>,
            optionTitle: @escaping (Value) -> LocalizedStringResource
        ) where Value: CaseIterable {
            self.init(title, selection: selection, allOptions: Array(Value.allCases), optionTitle: optionTitle)
        }
    }
}


extension Impl {
    /// Wrapper view for a single editable demographics data field.
    ///
    /// Manages the field's empty/answered validation and propagates the value up to the containing ``Impl`` and ``DemographicsForm``.
    private struct DemographicsComponent<Value, Content: View>: View {
        @Environment(DemographicsData.self) private var data
        
        private let valueKeyPath: ReferenceWritableKeyPath<DemographicsData, Value?>
        private let isNoSelectionValue: (Value) -> Bool
        private let content: @MainActor (Binding<Value?>, _ isEmpty: Bool) -> Content
        
        var body: some View {
            @Bindable var data = data
            let binding = Binding<Value?> {
                data[keyPath: valueKeyPath]
            } set: {
                data[keyPath: valueKeyPath] = $0
            }
            let isEmpty = binding.wrappedValue.map(isNoSelectionValue) ?? true
            content(binding, isEmpty)
                .preference(
                    key: EntryMissingValuePreferenceKey.self,
                    value: isEmpty
                )
        }
        
        init(
            _ valueKeyPath: ReferenceWritableKeyPath<DemographicsData, Value?>,
            isNoSelectionValue: @escaping (Value) -> Bool,
            @ViewBuilder content: @escaping @MainActor (_ binding: Binding<Value?>, _ isEmpty: Bool) -> Content
        ) {
            self.valueKeyPath = valueKeyPath
            self.isNoSelectionValue = isNoSelectionValue
            self.content = content
        }
        
        init(
            _ valueKeyPath: ReferenceWritableKeyPath<DemographicsData, Value?>,
            noSelectionValue: Value?...,
            @ViewBuilder content: @escaping @MainActor (_ binding: Binding<Value?>, _ isEmpty: Bool) -> Content
        ) where Value: Equatable {
            self.valueKeyPath = valueKeyPath
            self.isNoSelectionValue = { noSelectionValue.contains($0) }
            self.content = content
        }
    }
    
    private struct EntryMissingValuePreferenceKey: PreferenceKey {
        static var defaultValue: Bool { false }
        
        static func reduce(value: inout Bool, nextValue: () -> Bool) {
            value = value || nextValue()
        }
    }
}


// MARK: Testing Support

extension Impl {
    private var testingSupportMenu: some ToolbarContent {
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
