//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import SpeziFoundation
import XCTest
import XCTestExtensions
import XCTHealthKit


final class TaskHandlingTests: MHCTestCase, @unchecked Sendable {
    @MainActor
    func testUpcomingTasksTabGeneral() throws {
        throw XCTSkip()
        try launchAppAndEnrollIntoStudy()
        goToTab(.upcoming)
    }
    
    
    @MainActor
    func testCompleteScheduledTaskViaAlwaysAvailableMenu() throws {
        try launchAppAndEnrollIntoStudy()
        goToTab(.upcoming)
        
        let completionMessage = app.collectionViews.staticTexts["Six-Minute Walk Test, Completed"]
        
        XCTAssert(app.collectionViews.buttons["Take Test: Six-Minute Walk Test"].waitForExistence(timeout: 2))
        XCTAssertFalse(completionMessage.exists)
        
        app.navigationBars["Tasks"].buttons["Perform Always Available Task"].tap()
        XCTAssert(app.buttons["Six-Minute Walk Test"].waitForExistence(timeout: 2))
        app.buttons["Six-Minute Walk Test"].tap()
        XCTAssert(app.buttons["Start Test"].waitForExistence(timeout: 2))
        app.buttons["Start Test"].tap()
        handleMotionAndFitnessAccessPrompt(timeout: .seconds(2))
        XCTAssert(app.staticTexts["Test Complete"].waitForExistence(timeout: 10))
        XCTAssert(app.staticTexts["Steps, 624"].exists)
        XCTAssert(app.staticTexts["Distance (m), 842"].exists)
        app.navigationBars.buttons["Close"].tap()
        XCTAssert(completionMessage.exists)
    }
    
    
    @MainActor
    func testECG() throws {
        try launchAppAndEnrollIntoStudy()
        goToTab(.upcoming)
        app.swipeUp()
        
        let completionMessage = app.collectionViews.staticTexts["ECG, Completed"]
        XCTAssert(app.collectionViews.buttons["Take ECG"].waitForExistence(timeout: 2))
        XCTAssertFalse(completionMessage.exists)
        app.navigationBars["Tasks"].buttons["Perform Always Available Task"].tap()
        XCTAssert(app.buttons["ECG"].waitForExistence(timeout: 2))
        app.buttons["ECG"].tap()
        
        XCTAssert(app.staticTexts["Taking an ECG with Your Apple Watch"].waitForExistence(timeout: 2))
        try launchAndAddSample(healthApp: .healthApp, .electrocardiogram())
        app.activate()
        XCTAssert(app.staticTexts["Success"].waitForExistence(timeout: 2))
        XCTAssert(app.staticTexts["Your ECG has successfully been recorded"].waitForExistence(timeout: 2))
        app.buttons["OK"].tap()
        
        XCTAssert(app.staticTexts["Your ECG has successfully been recorded"].waitForNonExistence(timeout: 2))
        XCTAssert(completionMessage.waitForExistence(timeout: 2))
    }
}


extension MHCTestCase {
    @MainActor
    func handleMotionAndFitnessAccessPrompt(timeout: Duration) {
        let app = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alertPredicate = NSPredicate(format: "label LIKE %@", "“*” would like to access your Motion & Fitness activity.")
        let alert = app.alerts.element(matching: alertPredicate)
        if alert.waitForExistence(timeout: timeout.timeInterval) {
            alert.buttons["Allow"].tap()
        }
    }
}
