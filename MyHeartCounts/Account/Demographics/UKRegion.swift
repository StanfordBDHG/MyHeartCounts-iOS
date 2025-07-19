//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


enum UKRegion: Int, Hashable, Sendable, CaseIterable, RawRepresentableAccountKey {
    case notSet = 0
    case england = 1
    case scotland = 2
    case wales = 3
    case northernIreland = 4
    
    var displayTitle: String {
        switch self {
        case .notSet:
            String(localized: "UK_REGION_NOT_SET")
        case .england:
            String(localized: "UK_REGION_ENGLAND")
        case .scotland:
            String(localized: "UK_REGION_SCOTLAND")
        case .wales:
            String(localized: "UK_REGION_WALES")
        case .northernIreland:
            String(localized: "UK_REGION_NORTHERN_IRELAND")
        }
    }
}


// MARK: County

extension UKRegion {
    struct County: Hashable, RawRepresentable, Sendable, CaseIterable, RawRepresentableAccountKey {
        let rawValue: String
        let displayTitle: LocalizedStringResource
    }
}


extension UKRegion.County {
    static let notSet = Self(rawValue: "notSet", displayTitle: "Not Set")
    
    static let allCases: [UKRegion.County] = [
        .notSet
    ]
    
    static let englishCounties: [UKRegion.County] = []
    static let scottishCounties: [UKRegion.County] = []
    static let welshCounties: [UKRegion.County] = []
    static let northernIrishCounties: [UKRegion.County] = []
}
