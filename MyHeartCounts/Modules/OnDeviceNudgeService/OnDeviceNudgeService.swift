//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SpeziAccount
import SpeziLLM
import SpeziLLMLocal
import SwiftUI


// MARK: - Enums and Data Models

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
    case invalidUserData
    case parsingFailed
    case accountNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidUserData:
            return "Invalid user demographic data"
        case .parsingFailed:
            return "Failed to parse LLM response"
        case .accountNotAvailable:
            return "User account not available"
        }
    }
}

private struct PredefinedNudgeDTO: Codable {
    let title: String
    let body: String
    let isLLMGenerated: Bool
}

private struct LLMNudgeResponse: Codable {
    let title: String
    let body: String
}


// MARK: - Helper Functions

private func loadPredefinedNudges() -> [String: [NudgeMessage]] {
    guard let url = Bundle.main.url(forResource: "PredefinedNudges", withExtension: "json") else {
        print("Error: PredefinedNudges.json not found in app bundle.")
        return [:]
    }
    
    guard let data = try? Data(contentsOf: url) else {
        print("Error: Could not load data from file.")
        return [:]
    }
    
    guard let decodedDTOs = try? JSONDecoder().decode([String: [PredefinedNudgeDTO]].self, from: data) else {
        print("Error: Failed to decode JSON. Check JSON structure.")
        return [:]
    }
    
    let finalNudges = decodedDTOs.mapValues { nudgeDTOArray in
        nudgeDTOArray.map { dto in
            NudgeMessage(
                title: dto.title,
                body: dto.body,
                isLLMGenerated: dto.isLLMGenerated,
                generatedAt: Date()
            )
        }
    }
    
    return finalNudges
}

nonisolated func parseLLMResponse(_ response: String) throws -> [NudgeMessage] {
    guard let jsonStart = response.range(of: "["),
          let jsonEnd = response.range(of: "]", options: .backwards) else {
        throw NudgeServiceError.parsingFailed
    }
    
    let jsonString = String(response[jsonStart.lowerBound..<jsonEnd.upperBound])
    guard let jsonData = jsonString.data(using: .utf8) else {
        throw NudgeServiceError.parsingFailed
    }
    
    let nudges = try JSONDecoder().decode([LLMNudgeResponse].self, from: jsonData)
    
    guard nudges.count == 7 else {
        throw NudgeServiceError.parsingFailed
    }
    
    return nudges.map { nudge in
        NudgeMessage(
            title: nudge.title,
            body: nudge.body,
            isLLMGenerated: true,
            generatedAt: Date()
        )
    }
}


// MARK: - Main Service Class

@Observable
final class OnDeviceNudgeService: Module, EnvironmentAccessible {
    // swiftlint:disable attributes
    @ObservationIgnored @Dependency(Account.self) private var account: Account?
    @ObservationIgnored @Dependency(LLMRunner.self) private var runner: LLMRunner
    @ObservationIgnored @Application(\.logger) private var logger
    // swiftlint:enable attributes
    
    private let predefinedNudges: [String: [NudgeMessage]]
    
    init() {
        self.predefinedNudges = loadPredefinedNudges()
    }
    
    // MARK: Public Interface
    
    @MainActor
    func createNudgeNotifications() async throws -> [NudgeMessage] {
        guard let account = account else {
            throw NudgeServiceError.accountNotAvailable
        }
        
        let userData = try await UserDataService.getUserDemographics(account: account)
        let daysSinceEnrollment = UserDataService.getDaysSinceEnrollment(dateOfEnrollment: userData.dateOfEnrollment)
        let participantGroup = userData.participantGroup ?? 1
        
        let shouldCreatePredefinedNudges: Bool
        let shouldCreateLLMNudges: Bool
        
        if participantGroup == 1 && daysSinceEnrollment == 7 {
            shouldCreatePredefinedNudges = true
            shouldCreateLLMNudges = false
        } else if participantGroup == 1 && daysSinceEnrollment == 14 {
            shouldCreatePredefinedNudges = false
            shouldCreateLLMNudges = true
        } else if participantGroup == 2 && daysSinceEnrollment == 7 {
            shouldCreatePredefinedNudges = false
            shouldCreateLLMNudges = true
        } else if participantGroup == 2 && daysSinceEnrollment == 14 {
            shouldCreatePredefinedNudges = true
            shouldCreateLLMNudges = false
        } else {
            shouldCreatePredefinedNudges = true
            shouldCreateLLMNudges = false
        }
        
        if shouldCreatePredefinedNudges {
            logger.info("Creating predefined nudges for user, language: \(userData.userLanguage)")
            return getPredefinedNudges(language: userData.userLanguage)
        } else if shouldCreateLLMNudges {
            logger.info("Creating LLM-generated nudges for user, language: \(userData.userLanguage)")
            return try await generateLLMNudges(userData: userData)
        }
        
        return []
    }
    
    // MARK: Context Building Methods
    
    nonisolated func buildAgeContext(age: Int) -> String {
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
    
    nonisolated func buildGenderContext(genderIdentity: GenderIdentity?) -> String {
        switch genderIdentity {
        case .male:
            return String(localized: .llmNudgeContextMale)
        case .female:
            return String(localized: .llmNudgeContextFemale)
        default:
            return ""
        }
    }
    
    nonisolated func buildComorbiditiesContext(comorbidities: Comorbidities?) -> String {
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
    
    nonisolated func buildStageContext(stageOfChange: StageOfChange?) -> String {
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
    
    nonisolated func buildEducationContext(educationLevel: EducationLevel?) -> String {
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
    
    nonisolated func buildLanguageContext(userLanguage: String) -> String {
        userLanguage == "es" ? String(localized: .llmNudgeContextSpanish) : ""
    }
    
    // MARK: LLM-related Methods
    
    @MainActor
    func generateLLMNudges(userData: UserDemographics) async throws -> [NudgeMessage] {
        do {
            let prompt = buildLLMPrompt(userData: userData)
            let currentRunner = self.runner
            let nudges = try await Self.generateWithLLM(prompt: prompt, runner: currentRunner)
            logger.info("Generated \(nudges.count) LLM nudges for user in \(userData.userLanguage)")
            return nudges
        } catch {
            logger.warning("LLM generation failed: \(error), falling back to predefined nudges")
            return getPredefinedNudges(language: userData.userLanguage)
        }
    }
    
    nonisolated func buildLLMPrompt(userData: UserDemographics) -> String {
        var contexts: [String] = []
        
        contexts.append(buildLanguageContext(userLanguage: userData.userLanguage))
        contexts.append(buildGenderContext(genderIdentity: userData.genderIdentity))
        if let dateOfBirth = userData.dateOfBirth {
            let age = UserDataService.calculateAge(dateOfBirth: dateOfBirth)
            contexts.append(buildAgeContext(age: age))
        }
        contexts.append(buildComorbiditiesContext(comorbidities: userData.comorbidities))
        contexts.append(buildStageContext(stageOfChange: userData.stageOfChange))
        contexts.append(buildEducationContext(educationLevel: userData.educationLevel))
        
        let contextString = contexts.filter { !$0.isEmpty }.joined(separator: " ")
        
        return String(localized: .llmNudgeSystemPrompt(contextString))
    }
    
    nonisolated static func generateWithLLM(prompt: String, runner: LLMRunner) async throws -> [NudgeMessage] {
        let llmSession: LLMLocalSession = runner(
            with: LLMLocalSchema(
                model: .llama3_2_1B_4bit
            )
        )
        
        let context =
        [
            [
                "role": "user",
                "content": prompt
            ]
        ]
        
        await MainActor.run {
            llmSession.customContext = context
        }
        
        var responseText = ""
        for try await token in try await llmSession.generate() {
            responseText.append(token)
        }
        
        return try parseLLMResponse(responseText)
    }
    
    @MainActor
    func getPredefinedNudges(language: String) -> [NudgeMessage] {
        predefinedNudges[language] ?? predefinedNudges["en"] ?? []
    }
}
