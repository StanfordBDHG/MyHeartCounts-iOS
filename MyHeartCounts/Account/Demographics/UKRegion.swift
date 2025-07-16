//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


enum UKRegion: Int, Hashable, Sendable, RawRepresentableAccountKey {
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


extension UKRegion {
    struct County: Hashable, RawRepresentable, Sendable {
        let rawValue: String
    }
}
