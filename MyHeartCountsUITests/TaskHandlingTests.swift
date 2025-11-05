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
    private let timedWalkTestDistance = switch Locale.current.measurementSystem {
    case .us:
        "2,762 ft"
    default:
        "842 m"
    }
    
    
    // also tests the Timed Walk Test UI
    @MainActor
    func testCompleteScheduledTaskViaAlwaysAvailableMenu() throws {
        try launchAppAndEnrollIntoStudy()
        goToTab(.upcoming)
        
        let completionMessage = app.collectionViews.staticTexts["Six-Minute Walk Test, Completed"]
        
        do {
            var numTries = 0
            while numTries < 10, !app.collectionViews.buttons["Take Test: Six-Minute Walk Test"].waitForExistence(timeout: 2) {
                app.swipeUp()
                numTries += 1
            }
        }
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
        XCTAssert(app.staticTexts["Distance, \(timedWalkTestDistance)"].exists)
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
    
    
    @MainActor
    func testHHDPastTimedWalkTests() throws {
        try launchAppAndEnrollIntoStudy()
        goToTab(.heartHealth)
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        app.staticTexts["Past Timed Walk/Run Test Results"].tap()
        sleep(for: .seconds(1))
        
        let testCellPred = NSPredicate(format: "label LIKE 'Six-Minute Walk Test, *'")
        var numTests: Int {
            app.buttons.matching(testCellPred).count
        }
        let numTestsBefore = numTests
        
        if case let button = app.buttons.element(matching: testCellPred),
           button.waitForExistence(timeout: 2) {
            button.firstMatch.tap()
            XCTAssert(app.navigationBars["Six-Minute Walk Test"].waitForExistence(timeout: 2))
            XCTAssert(app.staticTexts["Number of Steps, 624"].waitForExistence(timeout: 2))
            XCTAssert(app.staticTexts["Distance, \(timedWalkTestDistance)"].waitForExistence(timeout: 2))
            app.navigationBars["0.5-Minute Walk Test"].buttons["BackButton"].tap()
        }
        
        app.buttons["Six-Minute Walk Test"].tap()
        
        app.buttons["Start Test"].tap()
        handleMotionAndFitnessAccessPrompt(timeout: .seconds(2))
        XCTAssert(app.staticTexts["Test Complete"].waitForExistence(timeout: 10))
        XCTAssert(app.staticTexts["Steps, 624"].exists)
        XCTAssert(app.staticTexts["Distance, \(timedWalkTestDistance)"].exists)
        app.otherElements["MHC.TimedWalkTestView"].navigationBars.buttons["Close"].tap()
        let numTestsAfter = numTests
        XCTAssertEqual(numTestsAfter, numTestsBefore + 1)
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
