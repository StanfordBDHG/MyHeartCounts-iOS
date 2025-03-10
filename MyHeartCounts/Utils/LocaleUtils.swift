//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Locale.Region {
    /// Returns, if possible, the region's corresponding flag emoji.
    ///
    /// Based on https://stackoverflow.com/a/30403199
    var flagEmoji: String? {
        let base: UInt32 = 127397
        var string = ""
        for scalar in self.identifier.unicodeScalars {
            guard let scalar = UnicodeScalar(base + scalar.value), scalar.properties.isEmoji else {
                return nil
            }
            string.unicodeScalars.append(scalar)
        }
        return string
    }
    
    /// Returns the localized name of the region, based on the specified locale, is possible.
    ///
    /// If no localized name can be determined, the region's underlying identifier is returned.
    func localizedName(in locale: Locale) -> String {
        locale.localizedString(forRegionCode: self.identifier) ?? self.identifier
    }
}


extension Locale.Language {
    /// Returns the localized name of the language, based on the specified locale, is possible.
    ///
    /// If no localized name can be determined, the language's underlying identifier is returned.
    func localizedName(in locale: Locale) -> String {
        locale.localizedString(forLanguageCode: self.maximalIdentifier) ?? self.minimalIdentifier
    }
}
