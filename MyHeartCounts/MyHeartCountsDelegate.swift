//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziFirebaseConfiguration
import SpeziHealthKit
import SpeziNotifications
import SpeziOnboarding
import SpeziScheduler
import SpeziStudy
import SwiftUI


class MyHeartCountsDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: MyHeartCountsStandard()) {
            let _ = ConfigureFirebaseApp.disallowDefaultConfiguration()
            SpeziAccessorModule()
            StudyManager()
            FirebaseLoader()
            HealthKit {
                // ???
            }
            Scheduler()
            Notifications()
        }
    }
}
