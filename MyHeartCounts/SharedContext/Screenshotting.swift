//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension FeatureFlags {
    /// Whether the app is currently being run by the automated screenshot script.
    static let isTakingDemoScreenshots = ProcessInfo.processInfo.environment["MHC_IS_TAKING_DEMO_SCREENSHOTS"] == "1"
}
