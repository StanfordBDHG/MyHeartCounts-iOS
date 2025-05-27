//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreMotion
import Foundation
import Spezi


@Observable
@MainActor
final class MotionManager: Module, EnvironmentAccessible, Sendable {
    enum Sensor: CaseIterable {
        case pedometer
        case altimeter
        case gyrometer
        case magnetometer
        case accelerometer
    }
}
