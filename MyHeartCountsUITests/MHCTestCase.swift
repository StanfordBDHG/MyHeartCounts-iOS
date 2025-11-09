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

/*
 Ideas for additional tests:
 - [dashboard] exercise mins vs step count (+ auto switch based on what's available!)
 - an onboarding test where we enter invalid values and get to the "you're not eligible" step
 */

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
    
    /// Launches the app and puts it in a state where the participant is logged in and enrolled into the study.
    ///
    /// - parameter enableDebugMode: Whether the app should force-enable its debug mode for this launch. Defaults to `false`.
    /// - parameter keepExistingData: Whether the app should keep the previous launch's state, w.r.t. stuff like e.g. the completed tasks. Defaults to `false`.
    /// - parameter heightEntryUnitOverride: Allows overriding the unit the app will use when manually entering a height quantity.
    ///     Allowed values are `cm`, `feet`, or `nil` (the default).
    /// - parameter weightEntryUnitOverride: Allows overriding the unit the app will use when manually entering a weight quantity.
    ///     Allowed values are `kg`, `lbs`, or `nil` (the default).
    /// - parameter extraLaunchArgs: Additional arguments that will be appended to the app's launch arguments. `nil` values will be skipped.
    @MainActor
    func launchAppAndEnrollIntoStudy(
        enableDebugMode: Bool = false,
        keepExistingData: Bool = false,
        skipHealthPermissionsHandling: Bool = false,
        skipGoingToHomeTab: Bool = false,
        heightEntryUnitOverride: String? = nil,
        weightEntryUnitOverride: String? = nil,
        extraLaunchArgs: [String?] = []
    ) throws {
        app.launchArguments = [
            "--useFirebaseEmulator",
            "--skipOnboarding",
            "--setupTestAccount", keepExistingData ? "keepExistingData" : nil,
            "--overrideStudyBundleLocation", try studyBundleUrl.path,
            "--disableAutomaticBulkHealthExport",
            "--forceEnableDebugMode", enableDebugMode ? "true" : "false",
            "--heightInputUnitOverride", heightEntryUnitOverride ?? "none",
            "--weightInputUnitOverride", weightEntryUnitOverride ?? "none"
        ].compactMap { $0 as String? }
        app.launchArguments += extraLaunchArgs.compactMap(\.self)
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 2))
        if !skipHealthPermissionsHandling {
            app.handleHealthKitAuthorization(timeout: 10) // Idea: maybe adjust this based on local vs CI?
            handleHealthRecordsAuthorization(
                healthRecordTypes: HealthRecordType.allCases,
                automaticallyShareUpdates: true,
                timeout: 10
            )
        }
        XCTAssert(app.tabBars.element.waitForExistence(timeout: 2))
        if !skipGoingToHomeTab {
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
}


extension MHCTestCase {
    enum RootLevelTab: String, CaseIterable {
        case home = "Home"
        case upcoming = "Tasks"
        case heartHealth = "Heart Health"
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
