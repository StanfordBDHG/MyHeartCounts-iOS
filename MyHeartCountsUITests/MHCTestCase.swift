//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import XCTest


class MHCTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    
    override func tearDown() {
        super.tearDown()
        MainActor.assumeIsolated {
            // After each test, we want the app to get fully reset.
            let app = XCUIApplication()
            app.terminate()
            app.delete(app: "My Heart Counts")
        }
    }
}
