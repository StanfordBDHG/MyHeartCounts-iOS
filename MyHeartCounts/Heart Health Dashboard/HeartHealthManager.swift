//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziHealthKit
import SwiftData


@Observable
final class HeartHealthManager: Module, EnvironmentAccessible {
    // swiftlint:disable attributes
    @ObservationIgnored @Dependency(HealthKit.self)
    private var healthKit
    // swiftlint:enable attributes
    
    @MainActor private(set) var layout: HealthDashboardLayout = []
    
    nonisolated init() {}
    
    func configure() {}
}
