//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziOnboarding
import SwiftUI


enum RegionPickerEntry: Identifiable {
    case region(Locale.Region)
    case somewhereElse
    
    var id: String {
        switch self {
        case .region(let region):
            region.identifier
        case .somewhereElse:
            "somewhereElse"
        }
    }
    
    var region: Locale.Region? {
        switch self {
        case .region(let region):
            region
        case .somewhereElse:
            nil
        }
    }
}
