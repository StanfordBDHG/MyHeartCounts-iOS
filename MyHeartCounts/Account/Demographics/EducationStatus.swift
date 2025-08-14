//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable inclusive_language

import Foundation


enum EducationStatusUS: Int, RawRepresentableAccountKey {
    case notSet = 0
    case didNotAttendSchool = 1
    case gradeSchool = 2
    case highSchool = 3
    /// Some college or vocational school or Associate Degree
    case someCollege = 4
    /// College graduate or Baccalaureate Degree
    case bachelor = 5
    case master = 6
    case doctoralDegree = 7
}


enum EducationStatusUK: Int, RawRepresentableAccountKey {
    case notSet = 0
    case didNotAttendSchool = 1
    case highSchool = 2
    /// Vocational training/apprenticeship/Diploma
    case vocationalTraining = 3
    /// College/University Graduate Degree
    case someCollege = 4
    /// College graduate or Baccalaureate Degree
    case master = 5
    case doctoralDegree = 6
}
