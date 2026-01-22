//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable implicitly_unwrapped_optional type_contents_order

import Foundation
import MHCStudyDefinitionExporter
import MyHeartCountsShared
import SpeziFoundation
import XCTest
import XCTestExtensions
import XCTHealthKit

/*
 Ideas for additional tests:
 - [dashboard] exercise mins vs step count (+ auto switch based on what's available!)
 - an onboarding test where we enter invalid values and get to the "you're not eligible" step
 */

/// The base class for all MHC UI tests.
///
/// This class sets up the ``app`` property, and provides the ``launchAppAndEnrollIntoStudy`` function.
class MHCTestCase: XCTestCase, @unchecked Sendable {
    static let loginCredentials = (email: "lelandstanford@stanford.edu", password: "StanfordRocks!")
    
    private static let tempDir = URL.temporaryDirectory.appending(component: "edu.stanford.MyHeartCounts.UITests", directoryHint: .isDirectory)
    
    @MainActor private(set) var app: XCUIApplication!
    @MainActor private(set) var studyBundleUrl: URL!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["MHC_IS_BEING_UI_TESTED"] = "1"
        if studyBundleUrl == nil {
            try FileManager.default.createDirectory(at: Self.tempDir, withIntermediateDirectories: true)
            studyBundleUrl = try export(to: Self.tempDir, as: .archive)
        }
    }
    
    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()
        app.terminate()
        app = nil
    }
    
    override class func tearDown() {
        try? FileManager.default.removeItem(at: Self.tempDir)
    }
    
    /// Launches the app and puts it in a state where the participant is logged in and enrolled into the study.
    ///
    /// - parameter enableDebugMode: Whether the app should force-enable its debug mode for this launch. Defaults to `false`.
    /// - parameter heightEntryUnitOverride: Allows overriding the unit the app will use when manually entering a height quantity.
    ///     Allowed values are `cm`, `feet`, or `nil` (the default).
    /// - parameter weightEntryUnitOverride: Allows overriding the unit the app will use when manually entering a weight quantity.
    ///     Allowed values are `kg`, `lbs`, or `nil` (the default).
    /// - parameter extraLaunchArgs: Additional arguments that will be appended to the app's launch arguments. `nil` values will be skipped.
    @MainActor
    func launchAppAndEnrollIntoStudy(
        enableDebugMode: Bool = false,
        testEnvironmentConfig: SetupTestEnvironmentConfig = .init(resetExistingData: true, loginAndEnroll: true),
        skipHealthPermissionsHandling: Bool = false,
        skipGoingToHomeTab: Bool = false,
        heightEntryUnitOverride: LaunchOptions.HeightInputUnitOverride = .none,
        weightEntryUnitOverride: LaunchOptions.WeightInputUnitOverride = .none,
        extraLaunchArgs: [String?] = []
    ) throws {
        app.launchArguments = Array {
            "--useFirebaseEmulator"
            testEnvironmentConfig.launchOptionArgs(for: .setupTestEnvironment)
            studyBundleUrl.launchOptionArgs(for: .overrideStudyBundleLocation)
            "--disableAutomaticBulkHealthExport"
            enableDebugMode.launchOptionArgs(for: .forceEnableDebugMode)
            heightEntryUnitOverride.launchOptionArgs(for: .heightInputUnitOverride)
            weightEntryUnitOverride.launchOptionArgs(for: .weightInputUnitOverride)
        }
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
        if !skipGoingToHomeTab {
            XCTAssert(app.tabBars.element.waitForExistence(timeout: 2))
            goToTab(.home)
            XCTAssert(app.staticTexts["My Heart Counts"].waitForExistence(timeout: 1))
            XCTAssert(app.staticTexts["Welcome to My Heart Counts"].exists)
            XCTAssert(app.staticTexts["WHO-5"].exists)
            XCTAssert(app.staticTexts["Disease QOL"].exists)
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
