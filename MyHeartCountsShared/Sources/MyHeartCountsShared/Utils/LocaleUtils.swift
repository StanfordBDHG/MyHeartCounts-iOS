//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import Foundation


extension Locale.Region {
    public enum EmojiPosition {
        case none
        case front
        case back
    }
    
    /// Returns, if possible, the region's corresponding flag emoji.
    ///
    /// Based on https://stackoverflow.com/a/30403199
    public var flagEmoji: String? {
        switch self {
        case .europe, .northernEurope, .westernEurope, .easternEurope, .southernEurope:
            return "🇪🇺"
        case .world:
            return "🇺🇳"
        case .unknown:
            return nil
        default:
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
    }
    
    /// Returns the localized name of the region, based on the specified locale, is possible.
    ///
    /// If no localized name can be determined, the region's underlying identifier is returned.
    public func localizedName(in locale: Locale, includeEmoji emojiPosition: EmojiPosition) -> String {
        let name = switch self {
        case .world:
            String(localized: "World")
        default:
            locale.localizedString(forRegionCode: self.identifier) ?? self.identifier
        }
        guard let flagEmoji else {
            return name
        }
        return switch emojiPosition {
        case .none:
            name
        case .front:
            "\(flagEmoji) \(name)"
        case .back:
            "\(name) \(flagEmoji)"
        }
    }
}


extension Locale.Language {
    /// Returns the localized name of the language, based on the specified locale, is possible.
    ///
    /// If no localized name can be determined, the language's underlying identifier is returned.
    @inlinable
    public func localizedName(in locale: Locale) -> String {
        locale.localizedString(forLanguageCode: self.maximalIdentifier) ?? self.minimalIdentifier
    }
}
