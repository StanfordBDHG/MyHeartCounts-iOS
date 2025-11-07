//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation


// MARK: US

struct EducationStatusUS: DemographicsSelectableSimpleValue {
    let id: String
    let displayTitle: LocalizedStringResource
    
    var rawValue: String { id }
}

extension EducationStatusUS {
    static let notSet = Self(id: "notSet", displayTitle: "Not Set")
    static let preferNotToState = Self(id: "preferNotToState", displayTitle: "Prefer not to state")
    
    static let options: [Self] = [
        Self(id: "didNotAttendSchool", displayTitle: "Didn't attend school"),
        Self(id: "gradeSchool", displayTitle: "Grade School"),
        Self(id: "highSchool", displayTitle: "High School"),
        /// Some college or vocational school or Associate Degree
        Self(id: "someCollege", displayTitle: "Some College"),
        /// College graduate or Baccalaureate Degree
        Self(id: "bachelor", displayTitle: "Cachelor"),
        Self(id: "master", displayTitle: "Master"),
        Self(id: "doctoralDegree", displayTitle: "Doctoral Degree")
    ]
}


// MARK: UK

struct EducationStatusUK: DemographicsSelectableSimpleValue {
    let id: String
    let displayTitle: LocalizedStringResource
    
    var rawValue: String { id }
}

extension EducationStatusUK {
    static let notSet = Self(id: "notSet", displayTitle: "Not Set")
    static let preferNotToState = Self(id: "preferNotToState", displayTitle: "Prefer not to state")
    
    static let options: [Self] = [
        Self(id: "didNotAttendSchool", displayTitle: "Didn't attend school"),
        Self(id: "highSchool", displayTitle: "High School"),
        /// Vocational training/apprenticeship/Diploma
        Self(id: "vocationalTraining", displayTitle: "Vocationa lTraining"),
        /// College/University Graduate Degree
        Self(id: "someCollege", displayTitle: "College/University Graduate Degree"),
        /// College graduate or Baccalaureate Degree
        Self(id: "master", displayTitle: "Master"),
        Self(id: "doctoralDegree", displayTitle: "Doctoral Degree")
    ]
}
