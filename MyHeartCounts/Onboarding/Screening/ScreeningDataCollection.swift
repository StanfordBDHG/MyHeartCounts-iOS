//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


@Observable
@MainActor
final class ScreeningDataCollection: Sendable {
    var dateOfBirth: Date = .now
    var region: Locale.Region?
    var speaksEnglish: Bool? // swiftlint:disable:this discouraged_optional_boolean
    var physicalActivity: Bool? // swiftlint:disable:this discouraged_optional_boolean
    
    var allPropertiesAreNonnil: Bool {
        // NOTE: ideally we'd simply use Mirror here to get a list of all properties,
        // and then do a simple `allSatisfy { value != nil }`, but that doesn't work,
        // because, even though we absolutely can use this code to get this result,
        // reading the property value through the Mirror won't call `access`, meaning that
        // using this propertu from SwiftUI won't cause view updates if any of the
        // properties change.
        region != nil && speaksEnglish != nil && physicalActivity != nil
    }
}
