//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable missing_docs

import Foundation

// Note: The hard-coded region identifiers used here are defined by the United Nations.
// See also: https://unstats.un.org/unsd/methodology/m49/


// MARK: Well-Known Regions

extension Locale.Region {
    @inlinable public static var africa: Locale.Region { Self("002") }
    @inlinable public static var northernAfrica: Locale.Region { Self("015") }
    @inlinable public static var subSaharanAfrica: Locale.Region { Self("202") }
    @inlinable public static var easternAfrica: Locale.Region { Self("202") }
    @inlinable public static var middleAfrica: Locale.Region { Self("017") }
    @inlinable public static var southernAfrica: Locale.Region { Self("018") }
    @inlinable public static var westernAfrica: Locale.Region { Self("011") }
    
    @inlinable public static var americas: Locale.Region { Self("019") }
    @inlinable public static var carribean: Locale.Region { Self("029") }
    @inlinable public static var centralAmerica: Locale.Region { Self("013") }
    @inlinable public static var southAmerica: Locale.Region { Self("005") }
    @inlinable public static var northernAmerica: Locale.Region { Self("021") }
    
    @inlinable public static var asia: Locale.Region { Self("142") }
    @inlinable public static var centralAsia: Locale.Region { Self("143") }
    @inlinable public static var easternAsia: Locale.Region { Self("030") }
    @inlinable public static var southEasternAsia: Locale.Region { Self("035") }
    @inlinable public static var southernAsia: Locale.Region { Self("034") }
    @inlinable public static var westernAsia: Locale.Region { Self("145") }
    
    @inlinable public static var europe: Locale.Region { Self("150") }
    @inlinable public static var easternEurope: Locale.Region { Self("151") }
    @inlinable public static var northernEurope: Locale.Region { Self("154") }
    @inlinable public static var southernEurope: Locale.Region { Self("039") }
    @inlinable public static var westernEurope: Locale.Region { Self("155") }
    
    @inlinable public static var oceania: Locale.Region { Self("009") }
    @inlinable public static var australiaAndNewZealand: Locale.Region { Self("053") }
    @inlinable public static var melanesia: Locale.Region { Self("054") }
    @inlinable public static var micronesia: Locale.Region { Self("057") }
    @inlinable public static var polynesia: Locale.Region { Self("061") }
}
