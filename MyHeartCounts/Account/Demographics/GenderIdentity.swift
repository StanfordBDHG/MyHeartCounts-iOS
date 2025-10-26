//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


enum GenderIdentity: Int, Hashable, Codable, CaseIterable {
    case preferNotToState = 0
    case male = 1
    case female = 2
    case transFemale = 3
    case transMale = 4
    case other = 5
}


extension GenderIdentity {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .preferNotToState:
            "GENDER_PREFER_NOT_TO_STATE"
        case .male:
            "GENDER_MALE"
        case .female:
            "GENDER_FEMALE"
        case .transFemale:
            "GENDER_TRANS_FEMALE"
        case .transMale:
            "GENDER_TRANS_MALE"
        case .other:
            "GENDER_OTHER"
        }
    }
}
