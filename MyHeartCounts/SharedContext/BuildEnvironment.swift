//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension ProcessInfo {
    /// Whether the app is currently running in the `TEST` configuration
    @_transparent static var isTestBuild: Bool {
        #if TEST
        true
        #else
        false
        #endif
    }
}
