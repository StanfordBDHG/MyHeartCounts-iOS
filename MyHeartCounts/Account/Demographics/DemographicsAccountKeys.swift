//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import HealthKit
import SpeziAccount
import SwiftUI


extension AccountKeyCategory {
    static let demographics = Self(title: "Demographics")
}


extension AccountDetails {
    typealias UKCounty = UKRegion.County
    
    
    @AccountKey(
        id: "mhcGenderIdentity",
        name: "Gender Identity",
        category: .demographics,
        options: .mutable,
        as: GenderIdentity.self,
        initial: .empty(.preferNotToState)
    )
    var mhcGenderIdentity: GenderIdentity?
    
    
    @AccountKey(id: "usRegion", name: "US State / Region", category: .demographics, options: .mutable, as: USRegion.self, initial: .empty(.notSet))
    var usRegion: USRegion?
    
    @AccountKey(id: "usZipCodePrefix", name: "First 3 Digits of ZIP Code", category: .demographics, options: .mutable, as: String.self)
    var usZipCodePrefix: String?
    
    @AccountKey(
        id: "householdIncomeUS",
        name: "Household Income",
        category: .demographics,
        options: .mutable,
        as: HouseholdIncomeUS.self,
        initial: .empty(.notSet)
    )
    var householdIncomeUS: HouseholdIncomeUS?
    
    
    @AccountKey(id: "ukRegion", name: "UK Country", category: .demographics, options: .mutable, as: UKRegion.self, initial: .empty(.notSet))
    var ukRegion: UKRegion?
    
    @AccountKey(
        id: "ukCounty",
        name: "UK County",
        category: .demographics,
        options: .mutable,
        as: UKCounty.self,
        initial: .empty(.notSet)
    )
    var ukCounty: UKCounty?
    
    @AccountKey(id: "ukPostcodePrefix", name: "First half of Postcode", category: .demographics, options: .mutable, as: String.self)
    var ukPostcodePrefix: String?
    
    @AccountKey(
        id: "householdIncomeUK",
        name: "Household Income",
        category: .demographics,
        options: .mutable,
        as: HouseholdIncomeUK.self,
        initial: .empty(.notSet)
    )
    var householdIncomeUK: HouseholdIncomeUK?
    
    
    @AccountKey(id: "heightInCM", name: "Height", category: .demographics, options: .mutable, as: Double.self)
    var heightInCM: Double?
    
    @AccountKey(id: "weightInKG", name: "Weight", category: .demographics, options: .mutable, as: Double.self)
    var weightInKG: Double?
    
    @AccountKey(id: "raceEthnicity", name: "Race / Ethnicity", category: .demographics, options: .mutable, as: RaceEthnicity.self)
    var raceEthnicity: RaceEthnicity?
    
    @AccountKey(
        id: "latinoStatus",
        name: "Latino / Hispanic?",
        category: .demographics,
        options: .mutable,
        as: LatinoStatusOption.self,
        initial: .empty(.notSet)
    )
    var latinoStatus: LatinoStatusOption?
    
    @AccountKey(
        id: "biologicalSexAtBirth",
        name: "Biological Sex at Birth",
        category: .demographics,
        options: .mutable,
        as: BiologicalSex.self,
        initial: .empty(.preferNotToState)
    )
    var biologicalSexAtBirth: BiologicalSex?
    
    @AccountKey(
        id: "bloodType",
        name: "Blood Type",
        category: .demographics,
        options: .mutable,
        as: HKBloodType.self,
        initial: .empty(.notSet)
    )
    var bloodType: HKBloodType?
    
    @AccountKey(
        id: "educationUS",
        name: "Educational Level",
        category: .demographics,
        options: .mutable,
        as: EducationStatusUS.self,
        initial: .empty(.notSet)
    )
    var educationUS: EducationStatusUS?
    
    @AccountKey(
        id: "educationUK",
        name: "Educational Level",
        category: .demographics,
        options: .mutable,
        as: EducationStatusUK.self,
        initial: .empty(.notSet)
    )
    var educationUK: EducationStatusUK?
    
    @AccountKey(
        id: "comorbidities",
        name: "Comorbidities",
        category: .demographics,
        options: .mutable,
        as: Comorbidities.self,
        initial: .empty([])
    )
    var comorbidities: Comorbidities?
    
    @AccountKey(
        id: "nhsNumber",
        name: "NHS Number",
        category: .demographics,
        options: .mutable,
        as: NHSNumber.self,
        initial: .empty(NHSNumber(unchecked: ""))
    )
    var nhsNumber: NHSNumber?
    
    @AccountKey(id: "futureStudies", name: "", category: .demographics, options: .mutable, as: Bool.self)
    var futureStudies: Bool?
    
    
    @AccountKey(
        id: "dateOfEnrollment",
        name: "Date of Enrollment",
        category: .other,
        options: .mutable,
        as: Date.self,
        initial: .empty(.distantPast),
    )
    var dateOfEnrollment: Date?
}


@KeyEntry(
    \.usRegion, \.usZipCodePrefix, \.householdIncomeUS, \.educationUS,
    \.ukRegion, \.ukCounty, \.ukPostcodePrefix, \.householdIncomeUK, \.educationUK,
    \.heightInCM, \.weightInKG, \.bloodType, \.nhsNumber, \.mhcGenderIdentity,
    \.raceEthnicity, \.latinoStatus,
    \.biologicalSexAtBirth, \.comorbidities, \.futureStudies,
    \.dateOfEnrollment
)
extension AccountKeys {}


// MARK: Codable conformances

extension HKBloodType: @retroactive Encodable, @retroactive Decodable, RawRepresentableAccountKey {}
