//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziAccount

enum UserDataService {
    static func getUserDemographics(account: Account) async throws -> UserDemographics {
        guard let details = await account.details else {
            throw NudgeServiceError.invalidUserData
        }
        
        return UserDemographics(
            genderIdentity: details.mhcGenderIdentity,
            dateOfBirth: details.dateOfBirth,
            comorbidities: details.comorbidities,
            stageOfChange: nil,
            educationLevel: determineEducationLevel(details: details),
            userLanguage: getUserLanguage(),
            dateOfEnrollment: details.dateOfEnrollment,
            participantGroup: 1,
            timeZone: TimeZone.current.identifier
        )
    }
    
    static func determineEducationLevel(details: AccountDetails) -> EducationLevel? {
        let hasUSCollege = details.educationUS.map { education in
            let collegeLevelIDs: Set<String> = ["someCollege", "bachelor", "master", "doctoralDegree"]
            return collegeLevelIDs.contains(education.id)
        } ?? false

        let hasUKCollege = details.educationUK.map { education in
            let collegeLevelIDs: Set<String> = ["vocationalTraining", "someCollege", "master", "doctoralDegree"]
            return collegeLevelIDs.contains(education.id)
        } ?? false
        
        if hasUSCollege || hasUKCollege {
            return .college
        }
                
        let hasUSHighSchool = details.educationUS.map { education in
            let highSchoolLevelIDs: Set<String> = ["didNotAttendSchool", "gradeSchool", "highSchool"]
            return highSchoolLevelIDs.contains(education.id)
        } ?? false

        let hasUKHighSchool = details.educationUK.map { education in
            let highSchoolLevelIDs: Set<String> = ["didNotAttendSchool", "highSchool"]
            return highSchoolLevelIDs.contains(education.id)
        } ?? false

        if hasUSHighSchool || hasUKHighSchool {
            return .highschool
        }

        return nil
    }
    
    static func getUserLanguage() -> String {
        guard let preferredLanguage = Locale.preferredLanguages.first else {
            return "en"
        }
        
        let locale = Locale(identifier: preferredLanguage)
        return locale.language.languageCode?.identifier ?? "en"
    }
    
    static func calculateAge(dateOfBirth: Date, present: Date = Date()) -> Int {
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: dateOfBirth, to: present).year ?? 0
        return age
    }
    
    static func getDaysSinceEnrollment(dateOfEnrollment: Date?) -> Int {
        guard let enrollmentDate = dateOfEnrollment else {
            return 0
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: enrollmentDate, to: Date()).day ?? 0
        return days
    }
}
