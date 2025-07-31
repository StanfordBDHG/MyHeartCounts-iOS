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


final class StudyParticipationTests: MHCTestCase, @unchecked Sendable {
    @MainActor
    func testStudyEnrollment() throws {
        app.launchArguments = [
            "--useFirebaseEmulator",
            "--skipOnboarding",
            "--setupTestAccount",
            "--overrideStudyBundleLocation", try studyBundleUrl.path,
            "--disableAutomaticBulkHealthExport"
        ]
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 2))
        try app.handleHealthKitAuthorization()
        XCTAssert(app.staticTexts["My Heart Counts"].waitForExistence(timeout: 5))
        XCTAssert(app.staticTexts["Welcome to My Heart Counts"].waitForExistence(timeout: 1))
        XCTAssert(app.staticTexts["Heart Risk"].waitForExistence(timeout: 1))
        XCTAssert(app.staticTexts["Par-Q+"].waitForExistence(timeout: 1))
        
        app.buttons["Your Account"].tap()
        XCTAssert(app.staticTexts["Leland Stanford"].waitForExistence(timeout: 1))
        XCTAssert(app.staticTexts["lelandstanford@stanford.edu"].waitForExistence(timeout: 1))
        XCTAssert(app.staticTexts["STUDY PARTICIPATIONS"].waitForExistence(timeout: 1))
        XCTAssert(app.staticTexts["My Heart Counts"].waitForExistence(timeout: 1))
        XCTAssert(app.staticTexts["Improve your cardiovascular health"].waitForExistence(timeout: 1))
    }
}
