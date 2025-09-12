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


class MHCTestCase: XCTestCase, @unchecked Sendable {
    private(set) var app: XCUIApplication! // swiftlint:disable:this implicitly_unwrapped_optional
    
    var studyBundleUrl: URL {
        get throws {
            try XCTUnwrap(Bundle(for: MHCTestCase.self).url(forResource: "mhcStudyBundle", withExtension: "spezistudybundle.aar"))
        }
    }
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        MainActor.assumeIsolated {
            app = XCUIApplication()
            app.launchEnvironment["MHC_IS_BEING_UI_TESTED"] = "1"
        }
    }
    
    override func tearDown() {
        super.tearDown()
        MainActor.assumeIsolated {
            // After each test, we want the app to get fully reset.
            app.terminate()
            app.delete(app: "My Heart Counts")
            app = nil
        }
    }
    
    @MainActor
    func launchAppAndEnrollIntoStudy() throws {
        app.launchArguments = [
            "--useFirebaseEmulator",
            "--skipOnboarding",
            "--setupTestAccount",
            "--overrideStudyBundleLocation", try studyBundleUrl.path,
            "--disableAutomaticBulkHealthExport"
        ]
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 2))
        app.handleHealthKitAuthorization()
        sleep(for: .seconds(2))
        goToTab(.home)
        XCTAssert(app.staticTexts["My Heart Counts"].waitForExistence(timeout: 5))
        XCTAssert(app.staticTexts["Welcome to My Heart Counts"].waitForExistence(timeout: 1))
        XCTAssertGreaterThan(
            ["Diet", "Par-Q+", "Six-Minute Walk Test", "Heart Risk"].count {
                app.staticTexts[$0].waitForExistence(timeout: 1)
            },
            2
        )
    }
}


extension MHCTestCase {
    enum RootLevelTab: String, CaseIterable {
        case home = "My Heart Counts"
        case upcoming = "Upcoming Tasks"
        case heartHealth = "Heart Health"
        case news = "News"
    }
    
    @MainActor
    func goToTab(_ tab: RootLevelTab) {
        let button = app.tabBars.buttons[tab.rawValue]
        XCTAssert(button.waitForExistence(timeout: 2))
        XCTAssert(button.isEnabled)
        XCTAssert(button.isHittable)
        button.tap()
    }
    
    @MainActor
    func openAccountSheet() {
        let button = app.navigationBars.buttons["Your Account"]
        XCTAssert(button.waitForExistence(timeout: 1))
        button.tap()
    }
}
