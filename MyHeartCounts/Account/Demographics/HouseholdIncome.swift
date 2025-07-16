//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation


protocol HouseholdIncome: CaseIterable, RawRepresentableAccountKey where AllCases: RandomAccessCollection {
    static var notSet: Self { get }
    
    var rawValue: UInt8 { get }
    var displayTitle: LocalizedStringResource { get }
}


// MARK: US

struct HouseholdIncomeUS: HouseholdIncome {
    let rawValue: UInt8
    let displayTitle: LocalizedStringResource
}

extension HouseholdIncomeUS {
    static let notSet = Self(rawValue: 0, displayTitle: "Not Set")
    
    static let allCases: [Self] = [
        .notSet,
        Self(rawValue: 1, displayTitle: "Less than $15,000"),
        Self(rawValue: 2, displayTitle: "$15,000 – $24,999"),
        Self(rawValue: 3, displayTitle: "$25,000 – $34,999"),
        Self(rawValue: 4, displayTitle: "$35,000 – $49,999"),
        Self(rawValue: 5, displayTitle: "$50,000 – $74,999"),
        Self(rawValue: 6, displayTitle: "$75,000 – $99,999"),
        Self(rawValue: 7, displayTitle: "$100,000 – $149,999"),
        Self(rawValue: 8, displayTitle: "$150,000 and above")
    ]
}


// MARK: UK

struct HouseholdIncomeUK: HouseholdIncome {
    let rawValue: UInt8
    let displayTitle: LocalizedStringResource
}

extension HouseholdIncomeUK {
    static let notSet = Self(rawValue: 0, displayTitle: "Not Set")
    
    static let allCases: [Self] = [
        .notSet,
        Self(rawValue: 1, displayTitle: "Less than £15,000"),
        Self(rawValue: 2, displayTitle: "£15,000 – £24,999"),
        Self(rawValue: 3, displayTitle: "£25,000 – £34,999"),
        Self(rawValue: 4, displayTitle: "£35,000 – £49,999"),
        Self(rawValue: 5, displayTitle: "£50,000 – £74,999"),
        Self(rawValue: 6, displayTitle: "£75,000 – £99,999"),
        Self(rawValue: 7, displayTitle: "£100,000 – £149,999"),
        Self(rawValue: 8, displayTitle: "£150,000 and above")
    ]
}
