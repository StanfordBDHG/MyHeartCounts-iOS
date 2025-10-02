//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


enum NicotineExposureCategoryValues: Int, Hashable, Sendable, CaseIterable {
    case neverSmoked = 0
    case quitMoreThan5YearsAgo = 1
    case quitWithin1To5Years = 2
    case quitWithinLastYearOrIsUsingNDS = 3
    case activelySmoking = 4
}


extension NicotineExposureCategoryValues {
    var shortDisplayTitle: LocalizedStringResource {
        switch self {
        case .neverSmoked:
            "Never"
        case .quitMoreThan5YearsAgo:
            "More than 5 years ago"
        case .quitWithin1To5Years:
            "1 to 5 years ago"
        case .quitWithinLastYearOrIsUsingNDS:
            "Within last year, or am using NDS"
        case .activelySmoking:
            "Actively smoking"
        }
    }
}
