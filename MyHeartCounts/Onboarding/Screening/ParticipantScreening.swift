//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziOnboarding
import SpeziStudy
import SpeziViews
import SwiftUI


///// Attempts to convert
//@MainActor
//func screeningOnboardingSteps(forParticipationCriteriaIn study: StudyDefinition) throws -> [AnyView] {
////    let leafCriteria = study.metadata.participationCriteria.criterion.allLeafs
////    guard !leafCriteria.isEmpty else {
////        return []
////    }
//    try screeningOnboardingSteps(for: study.metadata.participationCriteria.criterion)
//}
//
//
//@MainActor
//func screeningOnboardingSteps(for criterion: StudyDefinition.ParticipationCriteria.Criterion) throws -> [AnyView] {
////    let leafCriteria = study.metadata.participationCriteria.criterion.allLeafs
////    guard !leafCriteria.isEmpty else {
////        return []
////    }
//    switch criterion {
//    case /*.any([]),*/ .all([]):
//        return []
//    case .all(let nested):
//        guard nested.allSatisfy(\.isLeaf) else {
//            throw SimpleError("Not-Yet-Supported Criteria Definition!")
//        }
//        return try nested.map { criterion in
//            switch criterion {
//            case .ageAtLeast(let minAge):
//                AgeCheck(requiredMinAgeInYears: minAge).intoAnyView()
//            case .isFromRegion(let region):
//                RegionCheck(allowedRegions: region).intoAnyView()
//            case .custom:
//                throw SimpleError("Not-Yet-Supported Criteria Definition!")
//            case .all:
//                fatalError()
//            }
//        }
//    case .ageAtLeast, .isFromRegion, .custom:
//        return try screeningOnboardingSteps(for: .all([criterion]))
//    }
//}


extension View {
    consuming func intoAnyView() -> AnyView {
        AnyView(self)
    }
}
