//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct USRegion: Hashable, Codable {
    let name: LocalizedStringResource
    let abbreviation: String
    
    init(name: LocalizedStringResource, abbreviation: String) {
        self.name = name
        self.abbreviation = abbreviation
    }
    
    init?(abbreviation: String) {
        if let region = Self.allKnownRegions.first(where: { $0.abbreviation.lowercased() == abbreviation.lowercased() }) {
            self = region
        } else {
            return nil
        }
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let abbreviation = try container.decode(String.self)
        guard let region = Self(abbreviation: abbreviation) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown abbreviation: '\(abbreviation)'"))
        }
        self = region
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(abbreviation)
    }
}


extension USRegion {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.abbreviation.lowercased() == rhs.abbreviation.lowercased()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(abbreviation)
    }
}


extension USRegion {
    static let notSet = Self(name: "Not Set", abbreviation: "")
    
    static let alabama = Self(name: "Alabama", abbreviation: "AL")
    static let alaska = Self(name: "Alaska", abbreviation: "AK")
    static let arizona = Self(name: "Arizona", abbreviation: "AZ")
    static let arkansas = Self(name: "Arkansas", abbreviation: "AR")
    static let california = Self(name: "California", abbreviation: "CA")
    static let colorado = Self(name: "Colorado", abbreviation: "CO")
    static let connecticut = Self(name: "Connecticut", abbreviation: "CT")
    static let delaware = Self(name: "Delaware", abbreviation: "DE")
    static let dc = Self(name: "District of Columbia", abbreviation: "DC") // swiftlint:disable:this identifier_name
    static let florida = Self(name: "Florida", abbreviation: "FL")
    static let georgia = Self(name: "Georgia", abbreviation: "GA")
    static let hawaii = Self(name: "Hawaii", abbreviation: "HI")
    static let idaho = Self(name: "Idaho", abbreviation: "ID")
    static let illinois = Self(name: "Illinois", abbreviation: "IL")
    static let indiana = Self(name: "Indiana", abbreviation: "IN")
    static let iowa = Self(name: "Iowa", abbreviation: "IA")
    static let kansas = Self(name: "Kansas", abbreviation: "KS")
    static let kentucky = Self(name: "Kentucky", abbreviation: "KY")
    static let louisiana = Self(name: "Louisiana", abbreviation: "LA")
    static let maine = Self(name: "Maine", abbreviation: "ME")
    static let maryland = Self(name: "Maryland", abbreviation: "MD")
    static let massachusetts = Self(name: "Massachusetts", abbreviation: "MA")
    static let michigan = Self(name: "Michigan", abbreviation: "MI")
    static let minnesota = Self(name: "Minnesota", abbreviation: "MN")
    static let mississippi = Self(name: "Mississippi", abbreviation: "MS")
    static let missouri = Self(name: "Missouri", abbreviation: "MO")
    static let montana = Self(name: "Montana", abbreviation: "MT")
    static let nebraska = Self(name: "Nebraska", abbreviation: "NE")
    static let nevada = Self(name: "Nevada", abbreviation: "NV")
    static let newHampshire = Self(name: "New Hampshire", abbreviation: "NH")
    static let newJersey = Self(name: "New Jersey", abbreviation: "NJ")
    static let newMexico = Self(name: "New Mexico", abbreviation: "NM")
    static let newYork = Self(name: "New York", abbreviation: "NY")
    static let northCarolina = Self(name: "North Carolina", abbreviation: "NC")
    static let northDakota = Self(name: "North Dakota", abbreviation: "ND")
    static let ohio = Self(name: "Ohio", abbreviation: "OH")
    static let oklahoma = Self(name: "Oklahoma", abbreviation: "OK")
    static let oregon = Self(name: "Oregon", abbreviation: "OR")
    static let pennsylvania = Self(name: "Pennsylvania", abbreviation: "PA")
    static let rhodeIsland = Self(name: "Rhode Island", abbreviation: "RI")
    static let southCarolina = Self(name: "South Carolina", abbreviation: "SC")
    static let southDakota = Self(name: "South Dakota", abbreviation: "SD")
    static let tennessee = Self(name: "Tennessee", abbreviation: "TN")
    static let texas = Self(name: "Texas", abbreviation: "TX")
    static let utah = Self(name: "Utah", abbreviation: "UT")
    static let vermont = Self(name: "Vermont", abbreviation: "VT")
    static let virginia = Self(name: "Virginia", abbreviation: "VA")
    static let washington = Self(name: "Washington", abbreviation: "WA")
    static let westVirginia = Self(name: "West Virginia", abbreviation: "WV")
    static let wisconsin = Self(name: "Wisconsin", abbreviation: "WI")
    static let wyoming = Self(name: "Wyoming", abbreviation: "WY")
    
    static let americanSamoa = Self(name: "American Samoa", abbreviation: "AS")
    static let guam = Self(name: "Guam", abbreviation: "GU")
    static let northernMarianaIslands = Self(name: "Northern Mariana Islands", abbreviation: "MP")
    static let puertoRico = Self(name: "Puerto Rico", abbreviation: "PR")
    static let trustTerritories = Self(name: "Trust Territories", abbreviation: "TT")
    static let virginIslands = Self(name: "Virgin Islands", abbreviation: "VI")
}


extension USRegion {
    static let allKnownRegions: [Self] = allStatesAndDC + otherTerritories
    
    static let allStatesAndDC: [Self] = [
        .alabama, .alaska, .arizona, .arkansas,
        .california, .colorado, .connecticut,
        .delaware, .dc,
        .florida,
        .georgia,
        .hawaii,
        .idaho, .illinois, .indiana, .iowa,
        .kansas, .kentucky,
        .louisiana,
        .maine, .maryland, .massachusetts, .michigan, .minnesota, .mississippi, .missouri, .montana,
        .nebraska, .nevada, .newHampshire, .newJersey, .newMexico, .newYork, .northCarolina, .northDakota,
        .ohio, .oklahoma, .oregon,
        .pennsylvania,
        .rhodeIsland,
        .southCarolina, .southDakota,
        .tennessee, .texas,
        .utah,
        .vermont, .virginia,
        .washington, .westVirginia, .wisconsin, .wyoming
    ]
    
    static let otherTerritories: [Self] = [
        .americanSamoa, .guam, .northernMarianaIslands, .puertoRico, .trustTerritories, .virginIslands
    ]
}
