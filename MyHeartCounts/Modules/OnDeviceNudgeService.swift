//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziAccount
import SwiftUI


// MARK: - Enums and Data Models

enum Disease: String, Codable { // add back in CaseIterable?
    case heartFailure = "Heart failure"
    case pulmonaryArterialHypertension = "Pulmonary arterial hypertension"
    case diabetes = "Diabetes"
    case achdSimple = "ACHD (simple)"
    case achdComplex = "ACHD (complex)"
}

enum StageOfChange: String, Codable {
    case precontemplation = "Precontemplation"
    case contemplation = "Contemplation"
    case preparation = "Preparation"
    case action = "Action"
    case maintenance = "Maintenance"
}

enum EducationLevel: String, Codable {
    case highschool = "Highschool"
    case college = "college"
}

struct NudgeMessage { // add back in Identifiable and the id variable?
    let title: String
    let body: String
    let isLLMGenerated: Bool
    let generatedAt: Date
}

struct UserDemographics: Sendable {
    let genderIdentity: GenderIdentity?
    let dateOfBirth: Date?
    let comorbidities: Comorbidities?
    let stageOfChange: StageOfChange?
    let educationLevel: EducationLevel?
    let userLanguage: String
    let dateOfEnrollment: Date?
    let participantGroup: Int?
    let timeZone: String?
}

enum NudgeServiceError: LocalizedError {
    case llmNotAvailable
    case invalidUserData
    case generationFailed
    case parsingFailed
    case resourceNotFound
    case accountNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .llmNotAvailable:
            return "Local LLM is not available"
        case .invalidUserData:
            return "Invalid user demographic data"
        case .generationFailed:
            return "Failed to generate nudges"
        case .parsingFailed:
            return "Failed to parse LLM response"
        case .resourceNotFound:
            return "Predefined nudge messages not found"
        case .accountNotAvailable:
            return "User account not available"
        }
    }
}

// MARK: - Main Service Class

class OnDeviceNudgeManager {
    @Environment(Account.self) private
    var account: Account?
    
    func getUserDemographics(account: Account) async throws -> UserDemographics {
        guard let details = await account.details else {
            throw NudgeServiceError.invalidUserData
        }
        
        return UserDemographics(
            genderIdentity: details.mhcGenderIdentity,
            dateOfBirth: details.dateOfBirth, // accessed same way in DemographicsData.swift, but id is not present in DemographicAccountKeys.swift
            comorbidities: details.comorbidities,
            stageOfChange: nil, // not available
            educationLevel: determineEducationLevel(details: details),
            userLanguage: getUserLanguage(),
            dateOfEnrollment: details.dateOfEnrollment,
            participantGroup: 1, // not available; currently hardcoded
            timeZone: TimeZone.current.identifier
        )
    }
    
    func determineEducationLevel(details: AccountDetails) -> EducationLevel?  {
        
        let hasUSCollege = details.educationUS.map {
            switch $0 {
            case .someCollege, .bachelor, .master, .doctoralDegree:
                return true
            default:
                return false
            }
        } ?? false

        let hasUKCollege = details.educationUK.map {
            switch $0 {
            case .vocationalTraining, .someCollege, .master, .doctoralDegree:
                return true
            default:
                return false
            }
        } ?? false
        
        if hasUSCollege || hasUKCollege {
            return .college
        }
                
        let hasUSHighSchool = details.educationUS.map {
            switch $0 {
            case .didNotAttendSchool, .gradeSchool, .highSchool:
                return true
            default:
                return false
            }
        } ?? false

        let hasUKHighSchool = details.educationUK.map {
            switch $0 {
            case .didNotAttendSchool, .highSchool:
                return true
            default:
                return false
            }
        } ?? false

        if hasUSHighSchool || hasUKHighSchool {
            return .highschool
        }

        return nil
    }
    
    func getUserLanguage() -> String {
        guard let preferredLanguage = Locale.preferredLanguages.first else {
            return "en"
        }
        
        let locale = Locale(identifier: preferredLanguage)
        return locale.language.languageCode?.identifier ?? "en"
    }
    
    func calculateAge(dateOfBirth: Date, present: Date = Date()) -> Int {
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: dateOfBirth, to: present).year ?? 0
        return age
    }
    
    func getDaysSinceEnrollment(dateOfEnrollment: Date?) -> Int {
        guard let enrollmentDate = dateOfEnrollment else {
            return 0
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: enrollmentDate, to: Date()).day ?? 0
        return days
    }
    
    // MARK: Context Building Methods
    func buildAgeContext(age: Int) -> String {
        var contexts = [String(localized: .llmNudgeContextAgeBase(Int32(age)))]
        
        if age > 34 {
            contexts.append(String(localized: .llmNudgeContextAgeLongTerm))
        }
        
        if age > 50 {
            contexts.append(String(localized: .llmNudgeContextAgeBoneHealth))
        }
        
        if age > 65 {
            contexts.append(String(localized: .llmNudgeContextAgeLowImpact))
        }
        
        return contexts.joined(separator: " ")
    }
    
    func buildGenderContext(genderIdentity: GenderIdentity?) -> String {
        switch genderIdentity {
        case .male:
            return String(localized: .llmNudgeContextMale)
        case .female:
            return String(localized: .llmNudgeContextFemale)
        default:
            return ""
        }
    }
    
    // example call: let comorbiditiesContext = buildDiseaseContext(comorbidities: account.details?.comorbidities)
    func buildComorbiditiesContext(comorbidities: Comorbidities?) -> String {
        guard let comorbidities = comorbidities else {
            return ""
        }
            
        var contexts: [String] = []

        // This helper checks if a comorbidity is selected.
        func isSelected(_ id: String) -> Bool {
            guard let comorbidity = Comorbidities.Comorbidity(id: id) else {
                return false
            }
            
            let status = comorbidities[comorbidity]
            
            if case .selected = status {
                return true
            } else {
                return false
            }
        }
        
        if isSelected("diabetes") {
            contexts.append(String(localized: .llmNudgeContextDiabetes))
        }
        
        if isSelected("heartFailure") {
            contexts.append(String(localized: .llmNudgeContextHeartFailure))
        }
        
        if isSelected("pulmonaryArterialHypertension") {
            contexts.append(String(localized: .llmNudgeContextPulmonaryArterialHypertension))
        }
        
        if isSelected("adultCongenitalHeartDisease") {
            contexts.append(String(localized: .llmNudgeContextAchd))
        }
        
        return contexts.joined(separator: " ")
    }
    
    func buildStageContext(stageOfChange: StageOfChange?) -> String {
        guard let stage = stageOfChange else {
            return ""
        }
        
        switch stage {
        case .precontemplation:
            return String(localized: .llmNudgeContextStagePrecontemplation)
        case .contemplation:
            return String(localized: .llmNudgeContextStageContemplation)
        case .preparation:
            return String(localized: .llmNudgeContextStagePreparation)
        case .action:
            return String(localized: .llmNudgeContextStageAction)
        case .maintenance:
            return String(localized: .llmNudgeContextStageMaintenance)
        }
    }
    
    func buildEducationContext(educationLevel: EducationLevel?) -> String {
        guard let level = educationLevel else {
            return ""
        }
        
        switch level {
        case .highschool:
            return String(localized: .llmNudgeContextHighSchool)
        case .college:
            return String(localized: .llmNudgeContextCollege)
        }
    }
    
    func buildLanguageContext(userLanguage: String) -> String {
        userLanguage == "es" ? String(localized: .llmNudgeContextSpanish) : ""
    }
}