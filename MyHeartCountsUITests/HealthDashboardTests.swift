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
    
    
    @MainActor
    func testHealthDashboardDataEntryBMIIndirect() throws {
        throw XCTSkip("TODO: 67kb + 186cm -> 19.37 BMI")
    }
    
    
    @MainActor
    func testNicotineExposureProcessing() throws {
        try launchAppAndEnrollIntoStudy()
        goToTab(.heartHealth)
        
        XCTAssert(app.buttons["Nicotine Exposure"].waitForExistence(timeout: 2))
        app.buttons["Nicotine Exposure"].tap()
        
        XCTAssert(app.navigationBars["Nicotine Exposure"].buttons["Add Data"].waitForExistence(timeout: 2))
        
        app.navigationBars["Nicotine Exposure"].buttons["Add Data"].tap()
        try app.navigateResearchKitQuestionnaire(title: "Dashboard - Smoking", steps: [ // NOTE: might want to rename the survey here?!
            .init(actions: [.selectOption(title: "Never smoked/vaped")])
        ])
        XCTAssert(app.staticTexts["Most Recent Response: Never Smoked"].waitForExistence(timeout: 2))
        
        app.navigationBars["Nicotine Exposure"].buttons["Add Data"].tap()
        try app.navigateResearchKitQuestionnaire(title: "Dashboard - Smoking", steps: [ // NOTE: might want to rename the survey here?!
            .init(actions: [.selectOption(title: "Quit >5 years ago")])
        ])
        XCTAssert(app.staticTexts["Most Recent Response: Quit more than 5 years ago"].waitForExistence(timeout: 2))
    }
    
    
    @MainActor
    func testDietScoreProcessing() throws {
        // not trivial bc the survey contains mutiple questions on a single page, and it's not easy to differentiate between them.
        throw XCTSkip("TODO")
//        try launchAppAndEnrollIntoStudy()
//        goToTab(.heartHealth)
//        
//        XCTAssert(app.buttons["Diet"].waitForExistence(timeout: 2))
//        app.buttons["Diet"].tap()
//        
//        XCTAssert(app.navigationBars["Diet"].waitForExistence(timeout: 2))
//        app.navigationBars["Diet"].buttons["Add Data"].tap()
//        
//        try app.navigateResearchKitQuestionnaire(title: "Diet", steps: [
//            .init(actions: [.continue]),
//        ])
    }
    
    
    @MainActor
    func testBloodPressureDataEntry() throws {
        let systolic = Int.random(in: 100...140)
        let diastolic = Int.random(in: 60...90)
        
        try launchAppAndEnrollIntoStudy()
        goToTab(.heartHealth)
        app.swipeUp()
        XCTAssert(app.buttons["Blood Pressure"].waitForExistence(timeout: 2))
        app.buttons["Blood Pressure"].tap()
        
        XCTAssert(app.navigationBars["Blood Pressure"].waitForExistence(timeout: 2))
        app.navigationBars["Blood Pressure"].buttons["Add Data"].tap()
        
        XCTAssert(app.navigationBars["Enter Blood Pressure"].waitForExistence(timeout: 2))
        
        app.textFields["QuantityDataEntry:Systolic Blood Pressure"].tap()
        app.textFields["QuantityDataEntry:Systolic Blood Pressure"].typeText("\(systolic)")
        app.textFields["QuantityDataEntry:Diastolic Blood Pressure"].tap()
        app.textFields["QuantityDataEntry:Diastolic Blood Pressure"].typeText("\(diastolic)")
        
        app.navigationBars["Enter Blood Pressure"].buttons["Save"].tap()
        
        XCTAssert(app.staticTexts["Most Recent Sample: \(systolic) over \(diastolic)"].waitForExistence(timeout: 5))
    }
}
