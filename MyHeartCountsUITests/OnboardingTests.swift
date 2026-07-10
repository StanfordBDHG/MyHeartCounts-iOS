//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import MyHeartCountsShared
import XCTest


final class OnboardingTests: MHCTestCase, Sendable {
    func testOnboardingFlow() throws {
        try supplyHealthCharacteristics()
        try launchAppAndEnrollIntoStudy(
            locale: .enUS,
            testEnvironmentConfig: .init(resetExistingData: true, loginAndEnroll: .skip),
            handlePermissionPrompts: false,
            skipGoingToHomeTab: true
        )
        let navigator = OnboardingNavigator(testCase: self)
        try navigator.navigateFullOnboardingFlow(
            region: .unitedStates,
            name: .init(givenName: "Leland", familyName: "Stanford"),
            credentials: .random(),
            signUpForExtraTrial: true,
            consentPresenceCheck: .dontCare
        )
        XCTAssert(app.staticTexts["Welcome to My Heart Counts"].waitForExistence(timeout: 5))
    }
    
    
    func testRegionEligibilityComingSoon() throws {
        try launchAppAndEnrollIntoStudy(
            locale: .enUS,
            testEnvironmentConfig: .init(resetExistingData: true, loginAndEnroll: .skip),
            handlePermissionPrompts: false,
            skipGoingToHomeTab: true
        )
        let navigator = OnboardingNavigator(testCase: self)
        navigator.navigateWelcome()
        try navigator.navigateEligibility(region: .unitedKingdom)
        XCTAssert(app.staticTexts["Coming Soon"].waitForExistence(timeout: 5))
    }
    
    func testRegionEligibilityNotSupported() throws {
        try launchAppAndEnrollIntoStudy(
            locale: .enUS,
            testEnvironmentConfig: .init(resetExistingData: true, loginAndEnroll: .skip),
            handlePermissionPrompts: false,
            skipGoingToHomeTab: true
        )
        let navigator = OnboardingNavigator(testCase: self)
        navigator.navigateWelcome()
        try navigator.navigateEligibility(region: .germany)
        XCTAssert(app.staticTexts["Region Not Yet Supported"].waitForExistence(timeout: 5))
    }
}
