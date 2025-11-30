//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import Foundation


extension LaunchOptions {
    /// Whether we should force-enable the debug mode, even if the account key is set to `false`.
    ///
    /// - Note: Specifying `false` for this option when the account key is `true` will not force-disable the debug mode.
    public static let forceEnableDebugMode = LaunchOption<Bool>("--forceEnableDebugMode", default: false)
    
    public static let overrideStudyBundleLocation = LaunchOption<URL?>("--overrideStudyBundleLocation", default: nil)
}
