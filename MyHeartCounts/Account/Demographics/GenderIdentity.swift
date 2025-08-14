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
    var displayTitle: String {
        switch self {
        case .preferNotToState:
            String(localized: "GENDER_PREFER_NOT_TO_STATE")
        case .male:
            String(localized: "GENDER_MALE")
        case .female:
            String(localized: "GENDER_FEMALE")
        case .transFemale:
            String(localized: "GENDER_TRANS_FEMALE")
        case .transMale:
            String(localized: "GENDER_TRANS_MALE")
        case .other:
            String(localized: "GENDER_OTHER")
        }
    }
}
