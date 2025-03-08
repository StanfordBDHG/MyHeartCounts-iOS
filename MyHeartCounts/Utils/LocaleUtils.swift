//
//  File.swift
//  MyHeartCounts
//
//  Created by Lukas Kollmer on 08.03.25.
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
    
    func localizedName(in locale: Locale) -> String {
        locale.localizedString(forRegionCode: self.identifier) ?? self.identifier
    }
}
