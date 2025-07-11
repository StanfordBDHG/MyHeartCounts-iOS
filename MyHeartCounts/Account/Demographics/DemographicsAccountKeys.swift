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
import SwiftUI


extension AccountKeyCategory {
    static let demographics = Self(title: "Demographics")
}

extension AccountDetails {
    @AccountKey(id: "heightInCM", name: "Height", category: .demographics, options: .default, as: Double.self)
    var heightInCM: Double?
    
    @AccountKey(id: "weightInKG", name: "Weight", category: .demographics, options: .default, as: Double.self)
    var weightInKG: Double?
    
    @AccountKey(id: "raceEthnicity", name: "Race / Ethnicity", category: .demographics, options: .mutable, as: RaceEthnicity.self)
    var raceEthnicity: RaceEthnicity?
    
    @AccountKey(id: "bloodType", name: "Blood Type", category: .demographics, options: .mutable, as: HKBloodType.self, initial: .empty(.notSet))
    var bloodType: HKBloodType?
    
    @AccountKey(id: "nhsNumber", name: "NHS Number", category: .demographics, options: .mutable, as: String.self)
    var nhsNumber: String?
}


@KeyEntry(\.heightInCM, \.weightInKG, \.raceEthnicity, \.bloodType, \.nhsNumber)
extension AccountKeys {}


// MARK: Codable conformances

extension HKBloodType: @retroactive Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        if let value = Self(rawValue: rawValue) {
            self = value
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid value \(rawValue)"))
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
