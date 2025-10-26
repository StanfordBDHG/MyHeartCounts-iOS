//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


enum BiologicalSex: Int, CaseIterable, RawRepresentableAccountKey {
    case preferNotToState = 0
    case male = 1
    case female = 2
    case intersex = 3
    
    var displayTitle: LocalizedStringResource {
        switch self {
        case .preferNotToState:
            "SEX_PREFER_NOT_TO_STATE"
        case .male:
            "SEX_MALE"
        case .female:
            "SEX_FEMALE"
        case .intersex:
            "SEX_INTERSEX"
        }
    }
}
