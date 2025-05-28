//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI
import UIKit


/// Opens the App's settings page in Settings.app
public struct OpenAppSettingsAction: Sendable {
    /// The specific settings page that should be opened.
    public enum Target: Sendable {
        /// The current app's general settings page within Settings.app
        case generalAppSettings
        /// The current app's notification settings page within Settings.app
        case notificationSettings
    }
    
    /// Opens the specified settings page, for the current app.
    @MainActor
    public func callAsFunction(_ target: Target = .generalAppSettings) {
        // SAFETY: all of these URL constants are provided by apple.
        // swiftlint:disable force_unwrapping
        let url: URL = switch target {
        case .generalAppSettings:
            URL(string: UIApplication.openSettingsURLString)!
        case .notificationSettings:
            URL(string: UIApplication.openNotificationSettingsURLString)!
        }
        // swiftlint:enable force_unwrapping
        UIApplication.shared.open(url)
    }
}


extension EnvironmentValues {
    /// Opens the current app's settings.
    @Entry public var openAppSettings = OpenAppSettingsAction()
}
