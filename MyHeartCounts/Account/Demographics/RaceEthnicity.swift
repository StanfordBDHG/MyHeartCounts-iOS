//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct RaceEthnicity: OptionSet, Hashable, Sendable, RawRepresentableAccountKey {
    let rawValue: UInt64
    
    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
    
//    init(from decoder: any Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        rawValue = try container.decode(RawValue.self)
//    }
//    
//    func encode(to encoder: any Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(rawValue)
//    }
}


extension RaceEthnicity {
    static let preferNotToState = Self(rawValue: 1 << 0)
    
    
    static let white = Self(rawValue: 1 << 1) // 1=White;
    static let black = Self(rawValue: 1 << 2) // 2=Black, African-American, or Negro;
    static let americanIndian = Self(rawValue: 1 << 3) // 3=American Indian;
    static let alaskaNative = Self(rawValue: 1 << 4) // 4=Alaska Native;
    static let asianIndian = Self(rawValue: 1 << 5) // 5=Asian Indian;
    static let chinese = Self(rawValue: 1 << 6) // 6=Chinise;
    static let filipino = Self(rawValue: 1 << 7) // 7=Filipino;
    static let japanese = Self(rawValue: 1 << 8) // 8=Japanese;
    static let korean = Self(rawValue: 1 << 9) // 9=Korean;
    static let vietnamese = Self(rawValue: 1 << 10) // 10=Vietnamese;
    static let pacificIslander = Self(rawValue: 1 << 11) // 11=Pacific Islander;
    static let other = Self(rawValue: 1 << 12) // 12=Not listed
    
    static let allOptions: [Self] = [
        .preferNotToState,
        .white, .black, .americanIndian, .alaskaNative, .asianIndian, .chinese, .filipino, .japanese, .korean, .vietnamese, .pacificIslander, .other
    ]
    
    var localizedDisplayTitle: String {
        if self.isEmpty {
            return String(localized: "RACE_NO_SELECTION")
        } else if self.contains(.preferNotToState) {
            return String(localized: "RACE_PREFER_NOT_TO_ANSWER")
        }
        var entries: [LocalizedStringResource] = []
        if self.contains(.white) {
            entries.append("RACE_WHITE")
        }
        if self.contains(.black) {
            entries.append("RACE_AFRICAN_AMERICAN")
        }
        if self.contains(.americanIndian) {
            entries.append("RACE_AMERICAN_INDIAN")
        }
        if self.contains(.alaskaNative) {
            entries.append("RACE_ALASKA_NATIVE")
        }
        if self.contains(.asianIndian) {
            entries.append("RACE_ASIAN_INDIAN")
        }
        if self.contains(.chinese) {
            entries.append("RACE_CHINESE")
        }
        if self.contains(.filipino) {
            entries.append("RACE_FILIPINO")
        }
        if self.contains(.japanese) {
            entries.append("RACE_JAPANESE")
        }
        if self.contains(.korean) {
            entries.append("RACE_KOREAN")
        }
        if self.contains(.vietnamese) {
            entries.append("RACE_VIETNAMESE")
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
