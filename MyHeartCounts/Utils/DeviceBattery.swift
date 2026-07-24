//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import UIKit


enum DeviceBattery {
    /// Whether the device is currently connected to external power.
    @MainActor static var isCharging: Bool {
        let device = UIDevice.current
        let wasMonitoringBattery = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer {
            device.isBatteryMonitoringEnabled = wasMonitoringBattery
        }
        switch device.batteryState {
        case .charging, .full:
            return true
        case .unplugged, .unknown:
            return false
        @unknown default:
            return false
        }
    }

    /// Whether expensive, deferrable work (e.g., large data uploads) should run right now.
    ///
    /// Returns `true` while charging, `false` in Low Power Mode, and otherwise falls back to
    /// whether the work last ran more than `staleness` ago — so that deferring never starves it entirely.
    @MainActor
    static func shouldRunDeferrableWork(lastRun: Date?, staleness: TimeInterval) -> Bool {
        if isCharging {
            return true
        }
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return false
        }
        guard let lastRun else {
            return true
        }
        return Date.now.timeIntervalSince(lastRun) > staleness
    }
}
