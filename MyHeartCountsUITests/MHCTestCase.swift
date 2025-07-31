//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import XCTest


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
}
