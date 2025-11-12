//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziLLM
import SpeziLLMLocal
import SwiftUI
import XCTest
@testable import MyHeartCounts


// swiftlint:disable type_body_length
@MainActor
final class OnDeviceNudgeServiceTests: XCTestCase {
    private var nudgeService: OnDeviceNudgeService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        nudgeService = OnDeviceNudgeService()
    }
    
    override func tearDown() async throws {
        nudgeService = nil
        try await super.tearDown()
    }
    
    // MARK: - Predefined Nudges Tests
    
    func testPredefinedNudgesLoading() throws {
        // Test that predefined nudges are loaded correctly
        let nudges = nudgeService.getPredefinedNudges(language: "en")
        
        XCTAssertEqual(nudges.count, 7, "Should have exactly 7 predefined nudges")
        XCTAssertFalse(nudges.isEmpty, "Predefined nudges should not be empty")
        
        // Test first nudge
        let firstNudge = nudges.first!
        XCTAssertEqual(firstNudge.title, "Get Moving This Week!")
        XCTAssertTrue(firstNudge.body.contains("Ready for the day"))
        XCTAssertFalse(firstNudge.isLLMGenerated, "Predefined nudges should not be LLM generated")
    }
    
    func testPredefinedNudgesSpanish() throws {
        let nudges = nudgeService.getPredefinedNudges(language: "es")
        
        XCTAssertEqual(nudges.count, 7, "Should have exactly 7 Spanish predefined nudges")
        XCTAssertFalse(nudges.isEmpty, "Spanish predefined nudges should not be empty")
        
        // Test first Spanish nudge
        let firstNudge = nudges.first!
        XCTAssertEqual(firstNudge.title, "¡A Moverse Esta Semana!")
        XCTAssertTrue(firstNudge.body.contains("¿Listo para el día"))
        XCTAssertFalse(firstNudge.isLLMGenerated, "Predefined nudges should not be LLM generated")
    }
    
    func testPredefinedNudgesFallback() throws {
        // Test fallback to English when language not found
        let nudges = nudgeService.getPredefinedNudges(language: "fr")
        
        XCTAssertEqual(nudges.count, 7, "Should fallback to English nudges")
        XCTAssertEqual(nudges.first?.title, "Get Moving This Week!")
    }
    
    // MARK: - Age Calculation Tests
    
    func testAgeCalculation() throws {
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -30, to: Date())!
        
        let age = UserDataService.calculateAge(dateOfBirth: birthDate)
        XCTAssertEqual(age, 30, "Age calculation should be correct")
    }
    
    func testAgeCalculationEdgeCase() throws {
        let calendar = Calendar.current
        let today = Date()
        let birthDate = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let age = UserDataService.calculateAge(dateOfBirth: birthDate)
        XCTAssertEqual(age, 0, "Age should be 0 for someone born yesterday")
    }
    
    // MARK: - Days Since Enrollment Tests
    
    func testDaysSinceEnrollment() throws {
        let calendar = Calendar.current
        let enrollmentDate = calendar.date(byAdding: .day, value: -14, to: Date())!
        
        let days = UserDataService.getDaysSinceEnrollment(dateOfEnrollment: enrollmentDate)
        XCTAssertEqual(days, 14, "Days since enrollment should be correct")
    }
    
    func testDaysSinceEnrollmentNil() throws {
        let days = UserDataService.getDaysSinceEnrollment(dateOfEnrollment: nil)
        XCTAssertEqual(days, 0, "Days since enrollment should be 0 when date is nil")
    }
    
    // MARK: - Context Building Tests
    
    func testAgeContextYoung() throws {
        let context = nudgeService.buildAgeContext(age: 25)
        XCTAssertTrue(context.contains("25 years old"))
        XCTAssertTrue(context.contains("short-term benefits"))
        XCTAssertFalse(context.contains("long-term risk"))
    }
    
    func testAgeContextMiddle() throws {
        let context = nudgeService.buildAgeContext(age: 45)
        XCTAssertTrue(context.contains("45 years old"))
        XCTAssertTrue(context.contains("short-term benefits"))
        XCTAssertTrue(context.contains("long-term risk"))
        XCTAssertTrue(context.contains("cardiovascular disease"))
    }
    
    func testAgeContextSenior() throws {
        let context = nudgeService.buildAgeContext(age: 70)
        XCTAssertTrue(context.contains("70 years old"))
        XCTAssertTrue(context.contains("weight bearing exercise"))
        XCTAssertTrue(context.contains("lower impact sports"))
    }
    
    func testGenderContextMale() throws {
        let context = nudgeService.buildGenderContext(genderIdentity: .male)
        XCTAssertTrue(context.contains("male"))
        XCTAssertTrue(context.contains("sports"))
        XCTAssertTrue(context.contains("cycling"))
    }
    
    func testGenderContextFemale() throws {
        let context = nudgeService.buildGenderContext(genderIdentity: .female)
        XCTAssertTrue(context.contains("female"))
        XCTAssertTrue(context.contains("group fitness"))
        XCTAssertTrue(context.contains("activities with friends"))
    }
    
    func testComorbiditiesContextDiabetes() throws {
        var comorbidities = Comorbidities()
        let diabetesObject = try XCTUnwrap(
            Comorbidities.Comorbidity(id: "diabetes"),
            "Error: Could not find the 'diabetes' comorbidity definition."
        )
        comorbidities[diabetesObject] = .selected(startDate: DateComponents())
        let context = nudgeService.buildComorbiditiesContext(comorbidities: comorbidities)
        XCTAssertTrue(context.contains("diabetes"))
        XCTAssertTrue(context.contains("insulin sensitivity"))
        XCTAssertTrue(context.contains("exercise is one of the most powerful therapies"))
    }
    
    func testComorbiditiesContextHeartFailure() throws {
        var comorbidities = Comorbidities()
        let heartFailureObject = try XCTUnwrap(
            Comorbidities.Comorbidity(id: "heartFailure"),
            "Error: Could not find the 'heartFailure' comorbidity definition."
        )
        comorbidities[heartFailureObject] = .selected(startDate: DateComponents())
        let context = nudgeService.buildComorbiditiesContext(comorbidities: comorbidities)
        XCTAssertTrue(context.contains("heart failure"))
        XCTAssertTrue(context.contains("low cardiac output"))
        XCTAssertTrue(context.contains("exercise improves overall fitness"))
    }
    
    func testComorbiditiesContextPAHAndACHD() throws {
        var comorbidities = Comorbidities()
        let PAHObject = try XCTUnwrap(
            Comorbidities.Comorbidity(id: "pulmonaryArterialHypertension"),
            "Error: Could not find the 'pulmonaryArterialHypertension' comorbidity definition."
        )
        comorbidities[PAHObject] = .selected(startDate: DateComponents())
        let ACHDObject = try XCTUnwrap(
            Comorbidities.Comorbidity(id: "adultCongenitalHeartDisease"),
            "Error: Could not find the 'adultCongenitalHeartDisease' comorbidity definition."
        )
        comorbidities[ACHDObject] = .selected(startDate: DateComponents())
        let context = nudgeService.buildComorbiditiesContext(comorbidities: comorbidities)
        XCTAssertTrue(context.contains("(PAH)"))
        XCTAssertTrue(context.contains("right side of the heart"))
        XCTAssertTrue(context.contains("cannot be cured"))
        XCTAssertTrue(context.contains("adult congenital heart disease"))
        XCTAssertTrue(context.contains("preload"))
        XCTAssertTrue(context.contains("venous return"))
    }
    
    func testStageContextPrecontemplation() throws {
        let context = nudgeService.buildStageContext(stageOfChange: .precontemplation)
        XCTAssertTrue(context.contains("pre-contemplation"))
        XCTAssertTrue(context.contains("does not plan to start exercising"))
    }
    
    func testStageContextAction() throws {
        let context = nudgeService.buildStageContext(stageOfChange: .action)
        XCTAssertTrue(context.contains("action stage"))
        XCTAssertTrue(context.contains("recently started exercising"))
    }
    
    func testEducationContextHighschool() throws {
        let context = nudgeService.buildEducationContext(educationLevel: .highschool)
        XCTAssertTrue(context.contains("high school"))
        XCTAssertTrue(context.contains("sixth-grade reading level"))
    }
    
    func testEducationContextCollege() throws {
        let context = nudgeService.buildEducationContext(educationLevel: .college)
        XCTAssertTrue(context.contains("higher education"))
        XCTAssertTrue(context.contains("12th grade reading comprehension"))
    }
    
    func testLanguageContextSpanish() throws {
        let context = nudgeService.buildLanguageContext(userLanguage: "es")
        XCTAssertTrue(context.contains("Spanish"))
        XCTAssertTrue(context.contains("Latin American Spanish"))
        XCTAssertTrue(context.contains("RAE guidelines"))
    }
    
    func testLanguageContextEnglish() throws {
        let context = nudgeService.buildLanguageContext(userLanguage: "en")
        XCTAssertTrue(context.isEmpty, "English context should be empty")
    }
    
    // MARK: - LLM Integration Tests
    
    func testLLMPromptBuilding() throws {
        let userData = try createMockUserData(
            age: 45,
            gender: .male,
            comorbidities: ["diabetes"],
            stageOfChange: .action,
            educationLevel: .college,
            language: "en"
        )
        
        let prompt = nudgeService.buildLLMPrompt(userData: userData)
        
        XCTAssertTrue(prompt.contains("7 motivational messages"))
        XCTAssertTrue(prompt.contains("push notification"))
        XCTAssertTrue(prompt.contains("45 years old"))
        XCTAssertTrue(prompt.contains("male"))
        XCTAssertTrue(prompt.contains("diabetes"))
        XCTAssertTrue(prompt.contains("action stage"))
        XCTAssertTrue(prompt.contains("higher education"))
    }
    
    func testLLMResponseParsing() throws {
        let mockResponse = """
        [
            {"title": "Test Title 1", "body": "Test body 1"},
            {"title": "Test Title 2", "body": "Test body 2"},
            {"title": "Test Title 3", "body": "Test body 3"},
            {"title": "Test Title 4", "body": "Test body 4"},
            {"title": "Test Title 5", "body": "Test body 5"},
            {"title": "Test Title 6", "body": "Test body 6"},
            {"title": "Test Title 7", "body": "Test body 7"}
        ]
        """
        
        let nudges = try parseLLMResponse(mockResponse)
        
        XCTAssertEqual(nudges.count, 7, "Should parse exactly 7 nudges")
        XCTAssertEqual(nudges.first?.title, "Test Title 1")
        XCTAssertEqual(nudges.first?.body, "Test body 1")
        XCTAssertTrue(nudges.first?.isLLMGenerated ?? false, "Should be marked as LLM generated")
    }
    
    func testLLMResponseParsingFailure() throws {
        let invalidResponse = "Invalid JSON response"
        
        XCTAssertThrowsError(try parseLLMResponse(invalidResponse)) { error in
            XCTAssertTrue(error is NudgeServiceError)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockUserData(
        participantGroup: Int = 1,
        daysSinceEnrollment: Int = 7,
        age: Int = 30,
        gender: GenderIdentity = .male,
        comorbidities: [String] = [],
        stageOfChange: StageOfChange? = nil,
        educationLevel: EducationLevel? = nil,
        language: String = "en"
    ) throws -> UserDemographics {
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -age, to: Date())!
        let enrollmentDate = calendar.date(byAdding: .day, value: -daysSinceEnrollment, to: Date())!
        
        var combinedComorbidities = Comorbidities()
        for id in comorbidities {
            let comorbidityObject = try XCTUnwrap(
                Comorbidities.Comorbidity(id: id),
                "Error: Could not find the '\(id)' comorbidity definition."
            )
            combinedComorbidities[comorbidityObject] = .selected(startDate: DateComponents())
        }
        
        return UserDemographics(
            genderIdentity: gender,
            dateOfBirth: birthDate,
            comorbidities: combinedComorbidities,
            stageOfChange: stageOfChange,
            educationLevel: educationLevel,
            userLanguage: language,
            dateOfEnrollment: enrollmentDate,
            participantGroup: participantGroup,
            timeZone: "America/New_York"
        )
    }
}
// swiftlint:enable type_body_length
