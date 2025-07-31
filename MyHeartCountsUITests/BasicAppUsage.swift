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


final class BasicAppUsage: MHCTestCase, @unchecked Sendable {
    @MainActor
    func testRootLevelNavigation() throws {
        try launchAppAndEnrollIntoStudy()
        
        goToTab(.upcoming)
        XCTAssert(app.navigationBars.staticTexts["Upcoming Tasks"].waitForExistence(timeout: 2))
        
        goToTab(.heartHealth)
        XCTAssert(app.navigationBars.staticTexts["Heart Health Dashboard"].waitForExistence(timeout: 2))
        
        goToTab(.news)
        XCTAssert(app.navigationBars.staticTexts["News & Information"].waitForExistence(timeout: 2))
        
        print(app.debugDescription)
    }
    
    
    @MainActor
    func testDemographicsSheet() throws {
        try launchAppAndEnrollIntoStudy()
        openAccountSheet()
        app.buttons["Demographics"].tap()
        XCTAssert(app.navigationBars.staticTexts["Demographics"].waitForExistence(timeout: 1))
    }
}
