//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import XCTest
import XCTestExtensions
import XCTHealthKit


final class BasicAppUsage: MHCTestCase, @unchecked Sendable {
    @MainActor
    func testRootLevelNavigation() throws {
        try launchAppAndEnrollIntoStudy()
        goToTab(.upcoming)
        XCTAssert(app.navigationBars.staticTexts["Tasks"].waitForExistence(timeout: 2))
        goToTab(.heartHealth)
        XCTAssert(app.navigationBars.staticTexts["Heart Health"].waitForExistence(timeout: 2))
        goToTab(.news)
        XCTAssert(app.navigationBars.staticTexts["News"].waitForExistence(timeout: 2))
    }
    
    
    @MainActor
    func testDemographicsSheet() throws {
        try launchHealthAppAndEnterCharacteristics(.init(
            bloodType: .aPositive,
            dateOfBirth: .init(year: 1998, month: 6, day: 2),
            biologicalSex: .male,
            skinType: .II,
            wheelchairUse: .no
        ))
        try launchAppAndEnrollIntoStudy()
        openAccountSheet()
        app.buttons["Demographics"].tap()
        XCTAssert(app.navigationBars["Demographics"].waitForExistence(timeout: 1))
        XCTAssert(app.navigationBars.staticTexts["Demographics"].waitForExistence(timeout: 1))
        do {
            let button = app.navigationBars["Demographics"].buttons["Testing Support"]
            XCTAssert(button.waitForExistence(timeout: 1))
            button.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            let optionTitle = "Add Height & Weight Samples"
            XCTAssert(app.buttons[optionTitle].waitForExistence(timeout: 1))
            app.buttons[optionTitle].tap()
            app.handleHealthKitAuthorization()
        }
        app.buttons["Read from Health App"].tap()
        print(app.debugDescription)
        XCTAssert(
            app.datePickers.matching(NSPredicate(format: "label = 'Date of Birth' AND value = '1998-06-02'")).element.waitForExistence(timeout: 2)
        )
        switch Locale.current.measurementSystem {
        case .us:
            XCTAssert(app.buttons["Height, 6‘ 1“"].waitForExistence(timeout: 2))
            XCTAssert(app.buttons["Weight, 154.32 lb"].waitForExistence(timeout: 2))
        default:
            XCTAssert(app.buttons["Height, 186 cm"].waitForExistence(timeout: 2))
            XCTAssert(app.buttons["Weight, 70 kg"].waitForExistence(timeout: 2))
        }
        
        app.staticTexts["Race / Ethnicity"].tap()
        app.buttons["Prefer not to Answer"].tap()
        app.buttons["White"].tap()
        app.buttons["Japanese"].tap()
        app.navigationBars["Race / Ethnicity"].buttons["Demographics"].tap()
        XCTAssert(app.buttons["Race / Ethnicity, White, Japanese"].waitForExistence(timeout: 1))
    }
    
    
    @MainActor
    func testInformativeContent() throws {
        try launchAppAndEnrollIntoStudy()
        let articleTaskCompletedLabel = app.staticTexts["Welcome to My Heart Counts, Completed"]
        XCTAssert(articleTaskCompletedLabel.waitForNonExistence(timeout: 2))
        do {
            let button = app.buttons["Read Article: Welcome to My Heart Counts"]
            XCTAssert(button.waitForExistence(timeout: 2))
            button.tap()
        }
        XCTAssert(app.images["stanford"].waitForExistence(timeout: 2))
        do {
            let pred = NSPredicate(format: "label BEGINSWITH 'We’re thrilled to have you on board.'")
            XCTAssert(app.staticTexts.element(matching: pred).waitForExistence(timeout: 1))
        }
        app.navigationBars.buttons["Close"].tap()
        XCTAssert(articleTaskCompletedLabel.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testFeedback() throws {
        try launchAppAndEnrollIntoStudy()
        openAccountSheet()
        app.swipeUp()
        app.staticTexts["Send Feedback"].tap()
        XCTAssert(app.navigationBars["Feedback"].waitForExistence(timeout: 2))
        let sendButton = app.navigationBars["Feedback"].buttons["Send"]
        XCTAssert(sendButton.exists)
        XCTAssertFalse(sendButton.isEnabled)
        app.textViews["MHC.FeedbackTextField"].typeText("Heyyyy ;)")
        XCTAssert(sendButton.isEnabled)
        sendButton.tap()
        XCTExpectFailure("Firestore rules are currently incorrectly configured")
        XCTAssert(app.navigationBars["Feedback"].waitForNonExistence(timeout: 2))
    }
}
