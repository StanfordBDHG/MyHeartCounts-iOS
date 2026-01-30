//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import UniformTypeIdentifiers
import SpeziLocalization
import XCTest


final class MHCScreenshotting: MHCTestCase, @unchecked Sendable {
    private var screenshotsDir: URL!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        /// The URL of the `MyHeartCounts-iOS` repository.
        ///
        /// The full value of `#filePath` is e.g. `/Users/lukas/Developer/Spezi/MyHeartCounts-iOS/MyHeartCountsUITests/Screenshotting/MHCScreenshotting.swift`;
        /// we then need to remove the last 3 path components to get the root of the codebase.
        screenshotsDir = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "screenshots", directoryHint: .isDirectory)
    }
    
    @MainActor
    func recordScreenshot(_ name: String) throws {
        let pngData = XCUIScreen.main.screenshot().pngRepresentation
        let localeKey = try XCTUnwrap(LocalizationKey(locale: appLocale)).description
        let dir = screenshotsDir.appending(path: localeKey, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileUrl = dir.appendingPathComponent(name, conformingTo: .png)
        try pngData.write(to: fileUrl)
    }
}


extension MHCScreenshotting {
    @MainActor
    func testTakeAppStoreScreenshots() throws {
        try runScreenshotsFlow(for: .enUS)
        try runScreenshotsFlow(for: .esUS)
    }
    
    
    @MainActor
    private func runScreenshotsFlow(for locale: Locale) throws {
        let isFirstRun = locale == .enUS
        try launchAppAndEnrollIntoStudy(
            locale: locale,
            skipHealthPermissionsHandling: !isFirstRun,
            // the "go to home tab" thing implies checking for the on-screen existence of certain texts, which will fail if the language isn't english.
            // we instead manually go to the home tab.
            skipGoingToHomeTab: true,
            extraLaunchArgs: [
                "--dashboardConsiderAllSleepData"
            ],
            extraEnvironmentEntries: [
                "MHC_IS_TAKING_DEMO_SCREENSHOTS": "1"
            ]
        )
        app.tabBars.buttons["MHC:Tab:Home"].tap()
        try recordScreenshot("Home Tab 1")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Read Article: '")).element.tap()
        try recordScreenshot("Welcome Article")
        app.navigationBars.buttons["Close"].tap()
        try recordScreenshot("Home Tab 2")
        
        app.tabBars.buttons["MHC:Tab:Heart Health"].tap()
        if isFirstRun { // only need to do this once
            openAccountSheet()
            app.swipeUp()
            app.buttons["Debug"].tap()
            app.swipeUp()
            app.buttons["Add Demo Data"].tap()
            sleep(for: .seconds(5)) // give it some time to add everything
            app.navigationBars["Debug Options"].buttons["BackButton"].tap()
            app.navigationBars.buttons["Close"].tap()
        }
        sleep(for: .seconds(2)) // give it some time to load
        try recordScreenshot("Dashboard")
    }
}
