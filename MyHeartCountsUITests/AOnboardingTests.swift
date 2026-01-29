//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import MyHeartCountsShared
import XCTest
import XCTestExtensions
import XCTHealthKit
import XCTSpeziAccount
import XCTSpeziNotifications


// named like this bc tests are run based on the alpabetic ordering of the test classes, and we want this one to run first.
final class AOnboardingTests: MHCTestCase, @unchecked Sendable {
//    @MainActor
//    func testAOnboardingFlow() throws {
//        return;
//        try launchHealthAppAndEnterCharacteristics(.init(
//            bloodType: .aPositive,
//            dateOfBirth: .init(year: 1998, month: 6, day: 2),
//            biologicalSex: .male,
//            skinType: .II,
//            wheelchairUse: .no
//        ))
//        try launchAppAndEnrollIntoStudy(
//            testEnvironmentConfig: .init(resetExistingData: true, loginAndEnroll: false),
//            skipHealthPermissionsHandling: true,
//            skipGoingToHomeTab: true,
//        )
//        try app.navigateOnboardingFlow(
//            region: .unitedStates,
//            name: .init(givenName: "Leland", familyName: "Stanford"),
//            email: Self.loginCredentials.email,
//            password: Self.loginCredentials.password,
//            signUpForExtraTrial: true,
//            sender: self
//        )
//    }
//    
//    @MainActor
//    func testReviewConsentForms() throws {
//        return;
//        try launchAppAndEnrollIntoStudy(testEnvironmentConfig: .init(resetExistingData: false, loginAndEnroll: true))
//        // check that the consent we just signed is showing up in the Account Sheet
//        openAccountSheet()
//        XCTAssert(app.staticTexts["Review Consent Forms"].waitForExistence(timeout: 2))
//        app.staticTexts["Review Consent Forms"].tap()
//        XCTAssert(app.collectionViews.cells.staticTexts["My Heart Counts Consent Form"].waitForExistence(timeout: 2))
//        app.collectionViews.cells.buttons.element(matching: NSPredicate(format: "label CONTAINS 'My Heart Counts Consent Form'")).firstMatch.tap()
//        sleep(for: .seconds(2))
//        let consentPdf = app.otherElements["QLPreviewControllerView"].textViews.element
//        XCTAssert(consentPdf.exists)
//        XCTAssert(consentPdf.staticTexts["My Heart Counts Consent Form"].exists)
//        XCTAssert(consentPdf.staticTexts["# STANFORD UNIVERSITY\n## CONSENT TO BE PART OF A RESEARCH STUDY"].exists)
//        XCTAssert(
//            consentPdf.staticTexts.element(
//                matching: NSPredicate(format: "label BEGINSWITH 'You are invited to participate in a research study, \"My Heart Counts,\"'")
//            )
//            .waitForExistence(timeout: 2)
//        )
//    }
}


extension XCUIApplication {
    func navigateOnboardingFlow( // swiftlint:disable:this function_parameter_count
        region: Locale.Region,
        name: PersonNameComponents,
        email: String,
        password: String,
        signUpForExtraTrial: Bool,
        sender: XCTestCase
    ) throws {
        navigateWelcome()
        try navigateEligibility(region: region)
        try navigateSignup(name: name, email: email, password: password)
        sleep(for: .seconds(5))
        navigateOnboardingDisclaimers()
        navigateConsentComprehension()
        navigateConsent(expectedName: name, signUpForExtraTrial: signUpForExtraTrial)
        navigateHealthKitAccess()
        if staticTexts["Health Records"].waitForExistence(timeout: 2) { // only included if Health Records are actually available
            navigateHealthRecords(sender)
        }
        navigateWorkoutPreferences()
        if staticTexts["Notifications"].waitForExistence(timeout: 2) { // this step is skipped if sufficient permissions have already been granted
            navigateNotifications()
        }
        navigateDemographics()
        navigateFinalOnboardingStep(signUpForExtraTrial: signUpForExtraTrial)
    }
    
    
    private func navigateWelcome() {
        let predicate = NSPredicate(format: "label MATCHES 'Welcome to the My Heart Counts(\\n| )Cardiovascular Health Study'")
        XCTAssert(staticTexts.element(matching: predicate).waitForExistence(timeout: 2))
        buttons["Continue"].tap()
    }
    
    
    private func navigateEligibility(region: Locale.Region) throws {
        let continueButton = collectionViews.firstMatch.buttons["Continue"]
        let ofAgeToggle = switches["Are you 18 years old or older?"].descendants(matching: .switch).firstMatch
        XCTAssert(ofAgeToggle.waitForExistence(timeout: 2))
        XCTAssertEqual(try XCTUnwrap(ofAgeToggle.value as? String), "0")
        ofAgeToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(for: .seconds(0.25))
        XCTAssertEqual(try XCTUnwrap(ofAgeToggle.value as? String), "1")
        buttons["What country do you currently live in?"].tap()
        sleep(for: .seconds(0.55))
        do {
            searchFields["Search"].firstMatch.tap()
            searchFields["Search"].firstMatch.typeText(try XCTUnwrap(region.name()))
            let countryButton = buttons[try XCTUnwrap(region.name(includeEmoji: true))]
            XCTAssert(countryButton.waitForExistence(timeout: 1))
            countryButton.tap()
            sleep(for: .seconds(0.25))
            swipeUp()
            XCTAssertFalse(continueButton.isEnabled)
        }
        otherElements["Screening Section, Language"].buttons["Yes"].tryToTapReallySoftlyMaybeThisWillMakeItWork()
        XCTAssertFalse(continueButton.isEnabled)
        otherElements["Screening Section, Apple ID Sharing"].buttons["No"].tryToTapReallySoftlyMaybeThisWillMakeItWork()
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
    }
    
    
    private func navigateSignup(name: PersonNameComponents, email: String, password: String) throws {
        XCTAssert(staticTexts["Your Account"].waitForExistence(timeout: 10))
        let isLoggedIn = staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "You are already logged in"))
            .element
            .waitForExistence(timeout: 2)
        if !isLoggedIn {
            defer {
                dismissSavePasswordAlert(timeout: 10)
            }
            try login(email: email, password: password)
            let alert = alerts["Invalid Credentials"]
            if alert.waitForNonExistence(timeout: 3) {
                // no "invalid credentials" alert showed up, meaning that we did not try to log in to a non-existant user.
                return
            }
            // we need to sign up instead of logging in
            alert.buttons["OK"].tap()
            
            buttons["Signup"].tap()
            sleep(for: .seconds(0.5))
            XCTAssertFalse(collectionViews.firstMatch.buttons["Signup"].isEnabled) // this ia a different button from the one we just tapped.
            try fillSignupForm(email: email, password: password, name: name)
            XCTAssert(collectionViews.firstMatch.buttons["Signup"].isEnabled)
            collectionViews.firstMatch.buttons["Signup"].tap()
        } else {
            if let firstName = name.givenName, let lastName = name.familyName {
                XCTAssert(staticTexts["\(firstName) \(lastName)"].waitForExistence(timeout: 2))
            }
            XCTAssert(staticTexts[email].waitForExistence(timeout: 2))
            buttons["Next"].tap()
        }
    }
    
    
    private func navigateOnboardingDisclaimers() {
        struct StepInfo {
            let title: String
            let bodyPrefix: String
            let learnMorePrefix: String
        }
        
        let steps = [
            StepInfo(
                title: "Study Overview & Participation",
                bodyPrefix: "You’re invited to join a Stanford research study",
                learnMorePrefix: "This research study is conducted by Stanford University School of Medicine researchers"
            ),
            StepInfo(
                title: "Trial Component",
                bodyPrefix: "You have the option to enroll",
                learnMorePrefix: "The optional trial uses a"
            ),
            StepInfo(
                title: "Data Collection & Privacy",
                bodyPrefix: "We will collect data from the Health app",
                learnMorePrefix: "The study collects data through your phone's sensors"
            ),
            StepInfo(
                title: "Risks, Benefits & Your Rights",
                bodyPrefix: "Participation is completely voluntary",
                learnMorePrefix: "Physical risks are minimal"
            )
        ]
        
        for step in steps {
            XCTAssert(staticTexts[step.title].waitForExistence(timeout: 2))
            XCTAssert(staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", step.bodyPrefix)).firstMatch.waitForExistence(timeout: 2))
            buttons["Learn More"].tap()
            XCTAssert(staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", step.learnMorePrefix)).firstMatch.waitForExistence(timeout: 2))
            navigationBars.buttons["Close"].tap()
            buttons["Continue"].tap()
        }
    }
    
    
    private func navigateConsent(expectedName: PersonNameComponents?, signUpForExtraTrial: Bool) { // swiftlint:disable:this function_body_length
        sleep(for: .seconds(2))
        XCTAssert(scrollViews.staticTexts["STANFORD UNIVERSITY"].waitForExistence(timeout: 2))
        XCTAssert(scrollViews.staticTexts["CONSENT TO BE PART OF A RESEARCH STUDY"].waitForExistence(timeout: 2))
        func scrollToSwitchAndEnable(
            identifier: String,
            isOn: Bool,
            expectedDirection: Direction,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            while !scrollViews.switches[identifier].isHittable {
                swipe(expectedDirection.opposite, velocity: .fast)
            }
            let toggle = scrollViews.switches[identifier].switches.firstMatch
            switch (toggle.value as? String, isOn) {
            case ("0", true), ("1", false):
                toggle.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            case ("0", false), ("1", true):
                break
            default:
                XCTFail("Unable to decode switch value", file: file, line: line)
            }
        }
        func scrollToDropdownAndSelect(
            identifier: String,
            option: String,
            expectedDirection: Direction,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            while !scrollViews.buttons[identifier].isHittable {
                swipe(expectedDirection.opposite, velocity: .fast)
            }
            scrollViews.buttons[identifier].tap()
            collectionViews.buttons[option].tap()
        }
//        scrollToSwitchAndEnable(identifier: "ConsentForm:future-studies", isOn: true, expectedDirection: .down)
        scrollToDropdownAndSelect(
            identifier: "ConsentForm:short-term-physical-activity-trial",
            option: signUpForExtraTrial ? "Yes" : "No",
            expectedDirection: .down
        )
        swipeUp()
        XCTAssertFalse(buttons["I Consent"].isEnabled)
        scrollViews["ConsentForm:sig"].swipeRight()
        if let firstName = expectedName?.givenName, let lastName = expectedName?.familyName {
            XCTAssert(staticTexts["Name: \(firstName) \(lastName)"].waitForExistence(timeout: 1))
        }
        sleep(for: .seconds(0.25))
        XCTAssert(buttons["I Consent"].isEnabled)
        buttons["I Consent"].tap()
        sleep(for: .seconds(0.5))
    }
    
    
    private func navigateConsentComprehension() {
        let continueButton = collectionViews.firstMatch.buttons["Continue"]
        if continueButton.exists {
            XCTAssertFalse(continueButton.isEnabled)
        }
        XCTAssert(staticTexts["Consent Survey"].waitForExistence(timeout: 2))
        otherElements["Screening Section, 0"].buttons["True"].tryToTapReallySoftlyMaybeThisWillMakeItWork()
        if continueButton.exists {
            XCTAssertFalse(continueButton.isEnabled)
        }
        otherElements["Screening Section, 1"].buttons["True"].tryToTapReallySoftlyMaybeThisWillMakeItWork()
        if continueButton.exists {
            XCTAssertFalse(continueButton.isEnabled)
        }
        swipeUp()
        otherElements["Screening Section, 2"].buttons["True"].tryToTapReallySoftlyMaybeThisWillMakeItWork()
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
    }
    
    
    private func navigateHealthKitAccess() {
        XCTAssert(staticTexts["HealthKit Access"].waitForExistence(timeout: 10))
        // ^it might take a bit for the previous step (consent upload) to finish)
        buttons["Grant Access"].tap()
        handleHealthKitAuthorization()
    }
    
    
    private func navigateHealthRecords(_ testCase: XCTestCase) {
        XCTAssert(staticTexts["Health Records"].waitForExistence(timeout: 2))
        buttons["Review Permissions"].tap()
        testCase.handleHealthRecordsAuthorization()
    }
    
    
    private func navigateNotifications() {
        XCTAssert(staticTexts["Notifications"].waitForExistence(timeout: 2))
        buttons["Allow Notifications"].tap()
        confirmNotificationAuthorization()
    }
    
    
    private func navigateWorkoutPreferences() {
        XCTAssert(staticTexts["Workout Preference"].waitForExistence(timeout: 2))
        XCTAssert(staticTexts["Cycling"].waitForExistence(timeout: 2))
        staticTexts["Cycling"].tap()
        swipeUp()
        buttons["Continue"].tap()
    }
    
    
    private func navigateDemographics() { // swiftlint:disable:this function_body_length
        XCTAssert(staticTexts["Demographics"].waitForExistence(timeout: 2))
        
        XCTAssert(navigationBars["Demographics"].waitForExistence(timeout: 1))
        XCTAssert(navigationBars.staticTexts["Demographics"].waitForExistence(timeout: 1))
        do {
            let button = navigationBars["Demographics"].buttons["Testing Support"]
            XCTAssert(button.waitForExistence(timeout: 1))
            button.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            let optionTitle = "Add Height & Weight Samples"
            XCTAssert(buttons[optionTitle].waitForExistence(timeout: 1))
            buttons[optionTitle].tap()
            handleHealthKitAuthorization()
        }
        buttons["Read from Health App"].tap()
        XCTAssert(
            datePickers.matching(NSPredicate(format: "label = 'Date of Birth' AND value = '1998-06-02'")).element.waitForExistence(timeout: 2)
        )
        switch Locale.current.measurementSystem {
        case .us:
            XCTAssert(buttons["Height, 6‘ 1“"].waitForExistence(timeout: 2))
            XCTAssert(buttons["Weight, 154.32 lb"].waitForExistence(timeout: 2))
        default:
            XCTAssert(buttons["Height, 186 cm"].waitForExistence(timeout: 2))
            XCTAssert(buttons["Weight, 70 kg"].waitForExistence(timeout: 2))
        }
        
        swipeUp()
        
        staticTexts["Race / Ethnicity"].tap()
        buttons["Prefer not to state"].tap()
        buttons["White"].tap()
        buttons["Alaska Native"].tap()
        navigationBars.buttons["BackButton"].tap()
        XCTAssert(buttons["Race / Ethnicity, White, Alaska Native"].waitForExistence(timeout: 1))
        
        staticTexts["Are you Hispanic/Latino?"].tap()
        buttons["No"].tap()
        navigationBars.buttons["BackButton"].tap()
        XCTAssert(buttons["Are you Hispanic/Latino?, No"].waitForExistence(timeout: 1))
        
        staticTexts["Comorbidities"].tap()
        buttons["Heart Failure"].tap()
        navigationBars.buttons["Done"].tap()
        navigationBars.buttons["BackButton"].tap()
        XCTAssert(buttons["Comorbidities, 1 selected"].waitForExistence(timeout: 1))
        
        staticTexts["US State / Territory"].tap()
        buttons["District of Columbia, DC"].tap()
        navigationBars.buttons["BackButton"].tap()
        XCTAssert(buttons["US State / Territory, DC"].waitForExistence(timeout: 1))
        
        if staticTexts["Education Level"].waitForExistence(timeout: 2) {
            staticTexts["Education Level"].tap()
            buttons["Master's Degree"].tap()
            navigationBars.buttons["BackButton"].tap()
            XCTAssert(buttons["Education Level, Master's Degree"].waitForExistence(timeout: 1))
        }
        
        staticTexts["Total Household Income"].tap()
        buttons["Prefer not to state"].tap()
        navigationBars.buttons["BackButton"].tap()
        
        staticTexts["Stage of Change"].tap()
        buttons["StageOfChangeButton:a"].tap()
        navigationBars.buttons["BackButton"].tap()
        XCTAssert(buttons["Stage of Change, A"].waitForExistence(timeout: 1))
        
        let continueButton = buttons["Continue"]
        while !continueButton.exists {
            swipeUp()
        }
        continueButton.tap()
    }
    
    
    private func navigateFinalOnboardingStep(signUpForExtraTrial: Bool) {
        XCTAssert(staticTexts["Welcome to My Heart Counts"].waitForExistence(timeout: 2))
        do {
            let trialTextPredicate = NSPredicate(format: "label CONTAINS %@", "After your baseline week, you'll begin the 2-week trial")
            let element = staticTexts.matching(trialTextPredicate).element
            if signUpForExtraTrial {
                XCTAssert(element.waitForExistence(timeout: 2))
            } else {
                XCTAssert(element.waitForNonExistence(timeout: 2))
            }
        }
        buttons["Start"].tap()
        XCTAssert(staticTexts["Today's Tasks"].waitForExistence(timeout: 10))
    }
}


extension Locale.Region {
    func name(includeEmoji: Bool = false) -> String? {
        switch (includeEmoji, self) {
        case (false, .unitedStates):
            "United States"
        case (true, .unitedStates):
            "🇺🇸 United States"
        case (false, .unitedKingdom):
            "United Kingdom"
        case (true, .unitedKingdom):
            "🇬🇧 United Kingdom"
        case (false, .germany):
            "Germany"
        case (true, .germany):
            "🇩🇪 Germany"
        default:
            nil
        }
    }
}
