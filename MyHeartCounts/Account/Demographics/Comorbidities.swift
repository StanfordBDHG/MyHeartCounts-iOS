//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct Comorbidities: OptionSet, Hashable, Sendable, RawRepresentableAccountKey {
    let rawValue: UInt64
    
    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(RawValue.self)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}


extension Comorbidities {
    static let diabetes = Self(rawValue: 1 << 1)
    static let heartFailure = Self(rawValue: 1 << 2)
    static let coronaryArteryDisease = Self(rawValue: 1 << 3)
    static let pulmonaryArterialHypertension = Self(rawValue: 1 << 4)
    static let adultCongenitalHeartDisease = Self(rawValue: 1 << 5)
    
    static let allOptions: [Self] = [
        .diabetes, .heartFailure, .coronaryArteryDisease, .pulmonaryArterialHypertension, .adultCongenitalHeartDisease
    ]
    
    var localizedDisplayTitle: String {
        if self.isEmpty {
            return String(localized: "COMORBIDITY_NONE")
        }
        var entries: [LocalizedStringResource] = []
        if self.contains(.diabetes) {
            entries.append("COMORBIDITY_DIABETES")
        }
        if self.contains(.heartFailure) {
            entries.append("COMORBIDITY_HEART_FAILURE")
        }
        if self.contains(.coronaryArteryDisease) {
            entries.append("COMORBIDITY_CAD")
        }
        if self.contains(.pulmonaryArterialHypertension) {
            entries.append("COMORBIDITY_PAH")
        }
        if self.contains(.adultCongenitalHeartDisease) {
            entries.append("COMORBIDITY_ACHD")
        }
        return entries.lazy
            .map { String(localized: $0) }
            .joined(separator: ", ")
    }
}
