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
    static let loginCredentials = (email: "lelandstanford@stanford.edu", password: "StanfordRocks!")
    
    private(set) var app: XCUIApplication! // swiftlint:disable:this implicitly_unwrapped_optional
    
    private var interruptionMonitorTokens: [any NSObjectProtocol] = []
    
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
            app.terminate()
        }
    }
    
    @MainActor
    func launchAppAndEnrollIntoStudy(
        enableDebugMode: Bool = false,
        keepExistingData: Bool = false,
        heightEntryUnitOverride: String? = nil
    ) throws {
        app.launchArguments = [
            "--useFirebaseEmulator",
            "--skipOnboarding",
            "--setupTestAccount", keepExistingData ? "keepExistingData" : nil,
            "--overrideStudyBundleLocation", try studyBundleUrl.path,
            "--disableAutomaticBulkHealthExport",
            "--forceEnableDebugMode", enableDebugMode ? "true" : "false",
            "--heightInputUnitOverride", heightEntryUnitOverride ?? "none"
        ].compactMap { $0 as String? }
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 2))
        app.handleHealthKitAuthorization(timeout: 10) // Idea: maybe adjust this based on local vs CI?
        XCTAssert(app.tabBars.element.waitForExistence(timeout: 2))
        goToTab(.home)
        XCTAssert(app.staticTexts["My Heart Counts"].waitForExistence(timeout: 1))
        XCTAssert(app.staticTexts["Welcome to My Heart Counts"].exists)
        XCTAssertGreaterThanOrEqual(
            ["Diet", "Par-Q+", "Six-Minute Walk Test", "Heart Risk"].count {
                app.staticTexts[$0].exists
            },
            2
        )
    }
}


extension MHCTestCase {
    enum RootLevelTab: String, CaseIterable {
        case home = "Home"
        case upcoming = "Tasks"
        case heartHealth = "Heart Health"
        case news = "News"
    }
    
    @MainActor
    func goToTab(_ tab: RootLevelTab) {
        let button = app.tabBars.buttons[tab.rawValue]
        XCTAssert(button.exists)
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
