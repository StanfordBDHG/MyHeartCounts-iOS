//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import XCTest
import XCTestExtensions
import XCTHealthKit
import XCTSpeziAccount
import XCTSpeziNotifications


final class AOnboardingTests: MHCTestCase {
    @MainActor
    func testAOnboardingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--useFirebaseEmulator",
            "--overrideStudyBundleLocation",
            try studyBundleUrl.path,
            "--disableAutomaticBulkHealthExport"
        ]
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 2))
        try app.navigateOnboardingFlow(
            region: .unitedStates,
            name: .init(givenName: "Leland", familyName: "Stanford"),
            email: "leland@stanford.edu",
            password: "testTest123",
            signUpForExtraTrial: true
        )
    }
}


extension XCUIApplication {
    func navigateOnboardingFlow(
        region: Locale.Region,
        name: PersonNameComponents,
        email: String,
        password: String,
        signUpForExtraTrial: Bool
    ) throws {
        navigateWelcome()
        try navigateEligibility(region: region)
        try navigateSignup(name: name, email: email, password: password)
        navigateOnboardingDisclaimers()
        navigateConsent(expectedName: name, signUpForExtraTrial: signUpForExtraTrial)
        navigateConsentComprehension()
        try navigateHealthKitAccess()
        navigateNotifications()
        navigateFinalOnboardingStep(signUpForExtraTrial: signUpForExtraTrial)
    }
    
    
    private func navigateWelcome() {
        XCTAssert(staticTexts["Welcome to the My Heart Counts Cardiovascular Health Study"].waitForExistence(timeout: 2))
        buttons["Continue"].tap()
    }
    
    
    private func navigateEligibility(region: Locale.Region) throws {
        let continueButtons = [navigationBars.firstMatch.buttons["Continue"], collectionViews.firstMatch.buttons["Continue"]]
        for button in continueButtons {
            XCTAssertFalse(button.isEnabled)
        }
        let ofAgeToggle = switches["Are you 18 years old or older?"].descendants(matching: .switch).firstMatch
        XCTAssert(ofAgeToggle.waitForExistence(timeout: 2))
        XCTAssertEqual(try XCTUnwrap(ofAgeToggle.value as? String), "0")
        ofAgeToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(for: .seconds(0.25))
        XCTAssertEqual(try XCTUnwrap(ofAgeToggle.value as? String), "1")
        for button in continueButtons {
            XCTAssertFalse(button.isEnabled)
        }
        buttons["What country do you currently live in?"].tap()
        sleep(for: .seconds(0.55))
        for button in continueButtons {
            XCTAssertFalse(button.isEnabled)
        }
        do {
            searchFields["Search"].firstMatch.tap()
            searchFields["Search"].firstMatch.typeText(try XCTUnwrap(region.name()))
            let countryButton = buttons[try XCTUnwrap(region.name(includeEmoji: true))]
            XCTAssert(countryButton.waitForExistence(timeout: 1))
            countryButton.tap()
            sleep(for: .seconds(0.25))
            for button in continueButtons {
                XCTAssertFalse(button.isEnabled)
            }
        }
        otherElements["Screening Section, Language"].buttons["Yes"].tap()
        for button in continueButtons {
            XCTAssertTrue(button.isEnabled)
        }
        continueButtons[0].tap()
    }
    
    
    private func navigateSignup(name: PersonNameComponents, email: String, password: String) throws {
        XCTAssert(staticTexts["Your Account"].waitForExistence(timeout: 10))
        let isLoggedIn = staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "You are already logged in"))
            .element
            .waitForExistence(timeout: 2)
        if !isLoggedIn {
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
                bodyPrefix: "You're invited to join a Stanford research study",
                learnMorePrefix: "This research study is conducted by Stanford University School of Medicine researchers"
            ),
            StepInfo(
                title: "Trial Component",
                bodyPrefix: "You have the option to enroll",
                learnMorePrefix: "The optional trial uses a"
            ),
            StepInfo(
                title: "Data Collection & Privacy",
                bodyPrefix: "We'll collect data from the Health app",
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
            navigationBars.buttons["Dismiss"].tap()
            buttons["Continue"].tap()
        }
    }
    
    
    private func navigateConsent(expectedName: PersonNameComponents?, signUpForExtraTrial: Bool) {
        sleep(for: .seconds(2))
        print(debugDescription)
        XCTAssert(scrollViews.staticTexts["STANFORD UNIVERSITY"].waitForExistence(timeout: 2))
        XCTAssert(scrollViews.staticTexts["CONSENT TO BE PART OF A RESEARCH STUDY"].waitForExistence(timeout: 2))
        func scrollToSwitchAndEnable(identifier: String, isOn: Bool, file: StaticString = #filePath, line: UInt = #line) {
            while !scrollViews.switches[identifier].isHittable {
                swipeUp(velocity: .fast)
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
        scrollToSwitchAndEnable(identifier: "ConsentForm:future-studies", isOn: true)
        scrollToSwitchAndEnable(identifier: "ConsentForm:short-term-physical-activity-trial", isOn: signUpForExtraTrial)
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
        let continueButtons = [navigationBars.firstMatch.buttons["Continue"], collectionViews.firstMatch.buttons["Continue"]]
        for button in continueButtons {
            XCTAssertFalse(button.isEnabled)
        }
        XCTAssert(staticTexts["Consent Comprehension"].waitForExistence(timeout: 2))
        otherElements["Screening Section, 0"].buttons["True"].tap()
        for button in continueButtons {
            XCTAssertFalse(button.isEnabled)
        }
        otherElements["Screening Section, 1"].buttons["True"].tap()
        for button in continueButtons {
            XCTAssertFalse(button.isEnabled)
        }
        otherElements["Screening Section, 2"].buttons["True"].tap()
        for button in continueButtons {
            XCTAssert(button.isEnabled)
        }
        continueButtons[0].tap()
    }
    
    
    private func navigateHealthKitAccess() throws {
        XCTAssert(staticTexts["HealthKit Access"].waitForExistence(timeout: 2))
        buttons["Grant Access"].tap()
        try handleHealthKitAuthorization()
    }
    
    
    private func navigateNotifications() {
        XCTAssert(staticTexts["Notifications"].waitForExistence(timeout: 2))
        buttons["Allow Notifications"].tap()
        confirmNotificationAuthorization()
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
        buttons["Complete"].tap()
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
