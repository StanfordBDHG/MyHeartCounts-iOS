//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable discouraged_optional_boolean

import Foundation
import HealthKit
import SpeziAccount
import SwiftUI


@Observable
@MainActor
final class DemographicsData {
    @ObservationIgnored private var initialDetails: AccountDetails
    @ObservationIgnored private var account: Account?
    @ObservationIgnored private var updateTask: Task<Void, any Error>?
    @ObservationIgnored private var shouldHandleUpdates = true
    
    var dateOfBirth: Date? {
        didSet { onChange() }
    }
    var genderIdentity: GenderIdentity? {
        didSet {
            defer {
                onChange()
            }
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
            defer {
                onChange()
            }
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
    var height: HKQuantity? {
        didSet { onChange() }
    }
    var weight: HKQuantity? {
        didSet { onChange() }
    }
    var raceEthnicity: RaceEthnicity? {
        didSet { onChange() }
    }
    var latinoStatus: LatinoStatusOption? {
        didSet { onChange() }
    }
    var bloodType: HKBloodType? {
        didSet { onChange() }
    }
    var comorbidities: Comorbidities? {
        didSet { onChange() }
    }
    var usRegion: USRegion? {
        didSet { onChange() }
    }
    var ukRegion: UKRegion? {
        didSet { onChange() }
    }
    var usEducationLevel: EducationStatusUS? {
        didSet { onChange() }
    }
    var ukEducationLevel: EducationStatusUK? {
        didSet { onChange() }
    }
    var usHouseholdIncome: HouseholdIncomeUS? {
        didSet { onChange() }
    }
    var ukHouseholdIncome: HouseholdIncomeUK? {
        didSet { onChange() }
    }
    var nhsNumber: NHSNumber? {
        didSet { onChange() }
    }
    var futureStudiesOptIn: Bool? {
        didSet { onChange() }
    }
    var stageOfChange: StageOfChangeOption? {
        didSet { onChange() }
    }
    
    init() {
        initialDetails = AccountDetails()
    }
    
    func populate(from account: Account) {
        self.account = account
        populate(from: account.details ?? AccountDetails())
    }
    
    private func populate(from details: AccountDetails) {
        shouldHandleUpdates = false
        defer {
            shouldHandleUpdates = true
        }
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
        usEducationLevel = details.educationUS
        ukEducationLevel = details.educationUK
        usHouseholdIncome = details.householdIncomeUS
        ukHouseholdIncome = details.householdIncomeUK
        nhsNumber = details.nhsNumber
        futureStudiesOptIn = details.futureStudies
        stageOfChange = details.stageOfChange
    }
    
    private func onChange(_ trigger: StaticString = #function) {
        guard shouldHandleUpdates, let account else {
            return
        }
        updateTask?.cancel()
        updateTask = Task {
            try await Task.sleep(for: .seconds(1))
            try await write(to: account)
        }
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
        write(usEducationLevel, to: \.educationUS)
        write(ukEducationLevel, to: \.educationUK)
        write(usHouseholdIncome, to: \.householdIncomeUS)
        write(ukHouseholdIncome, to: \.householdIncomeUK)
        write(nhsNumber, to: \.nhsNumber)
        write(futureStudiesOptIn, to: \.futureStudies)
        write(stageOfChange, to: \.stageOfChange)
        let modifications = try AccountModifications(modifiedDetails: updated, removedAccountDetails: removed)
        try await account.accountService.updateAccountDetails(modifications)
        print("Did write demographics values to account details")
    }
}
