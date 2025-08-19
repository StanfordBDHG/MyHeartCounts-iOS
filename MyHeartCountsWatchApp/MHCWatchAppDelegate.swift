//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi
import SpeziFoundation
import SpeziHealthKit

final class MHCWatchAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: MHCWatchAppStandard()) {
            HealthKit {
                RequestReadAccess(
                    quantity: [.heartRate, .activeEnergyBurned, .distanceWalkingRunning]
                )
                RequestWriteAccess(other: [SampleType.workout])
            }
            PhoneConnection()
            WorkoutManager()
        }
    }
}
