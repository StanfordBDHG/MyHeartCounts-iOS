//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct RaceEthnicity: OptionSet, Hashable, Codable, Sendable {
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


extension RaceEthnicity {
    static let preferNotToState = Self(rawValue: 1 << 0)
    
    static let americanIndian = Self(rawValue: 1 << 1)
    static let alaskaNative = Self(rawValue: 1 << 2)
    static let asian = Self(rawValue: 1 << 3)
    static let africanAmerican = Self(rawValue: 1 << 4)
    static let caucasian = Self(rawValue: 1 << 5)
    static let hispanicOrLatino = Self(rawValue: 1 << 6)
    /// Middle East and Northern Africa
    static let mena = Self(rawValue: 1 << 7)
    static let nativeHawaiian = Self(rawValue: 1 << 8)
    static let pacificIslander = Self(rawValue: 1 << 9)
    static let other = Self(rawValue: 1 << 10)
    
    static let allOptions: [Self] = [
        .preferNotToState,
        .americanIndian, .alaskaNative, .asian, .africanAmerican, .caucasian,
        .hispanicOrLatino, .mena, .nativeHawaiian, .pacificIslander, .other
    ]
    
    var localizedDisplayTitle: String {
        if self.isEmpty {
            return String(localized: "RACE_NO_SELECTION")
        } else if self.contains(.preferNotToState) {
            return String(localized: "RACE_PREFER_NOT_TO_ANSWER")
        }
        var entries: [LocalizedStringResource] = []
        if self.contains(.americanIndian) {
            entries.append("RACE_AMERICAN_INDIAN")
        }
        if self.contains(.alaskaNative) {
            entries.append("RACE_ALASKA_NATIVE")
        }
        if self.contains(.asian) {
            entries.append("RACE_ASIAN")
        }
        if self.contains(.africanAmerican) {
            entries.append("RACE_AFRICAN_AMERICAN")
        }
        if self.contains(.caucasian) {
            entries.append("RACE_CAUCASIAN")
        }
        if self.contains(.hispanicOrLatino) {
            entries.append("RACE_HISPANIC_LATINO")
        }
        if self.contains(.mena) {
            entries.append("RACE_MENA")
        }
        if self.contains(.nativeHawaiian) {
            entries.append("RACE_NATIVE_HAWAIIAN")
        }
        if self.contains(.pacificIslander) {
            entries.append("RACE_PACIFIC_ISLANDER")
        }
        if self.contains(.other) {
            entries.append("RACE_OTHER")
        }
        return entries.lazy
            .map { String(localized: $0) }
            .joined(separator: ", ")
    }
}
