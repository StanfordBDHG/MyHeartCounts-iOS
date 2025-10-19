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


class HealthDashboardTests: MHCTestCase, @unchecked Sendable {
    @MainActor
    func testHealthDashboardDataEntryBMIDirect() throws {
        let value = Int.random(in: 20...50)
        try launchAppAndEnrollIntoStudy()
        goToTab(.heartHealth)
        XCTAssert(app.buttons["Body Mass Index"].waitForExistence(timeout: 2))
        app.buttons["Body Mass Index"].tap()
        sleep(for: .seconds(2))
        XCTAssert(app.navigationBars["Body Mass Index"].buttons["Add Data"].waitForExistence(timeout: 2))
        app.navigationBars["Body Mass Index"].buttons["Add Data"].tap()
        
        XCTAssert(app.navigationBars["Enter BMI"].waitForExistence(timeout: 2))
        app.segmentedControls.buttons["BMI"].tap()
        
        let doneButton = app.navigationBars["Enter BMI"].buttons["Save"]
        XCTAssertFalse(doneButton.isEnabled)
        let textField = app.textFields["QuantityDataEntry:Body Mass Index"]
        XCTAssert(textField.waitForExistence(timeout: 2))
        textField.tap()
        textField.typeText("\(value)")
        XCTAssert(doneButton.wait(for: \.isEnabled, toEqual: true, timeout: 1))
        doneButton.tap()
        
        XCTAssert(app.staticTexts["Most Recent Sample: \(value)"].waitForExistence(timeout: 2))
    }
}
