//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable attributes

import Spezi
import SpeziFirebaseConfiguration
import SpeziHealthKit
import SpeziNotifications
import SpeziOnboarding
import SpeziScheduler
import SpeziStudy
import SwiftUI


@Observable
class MyHeartCountsDelegate: SpeziAppDelegate { // swiftlint:disable:this file_types_order
    override var configuration: Configuration {
        Configuration(standard: MyHeartCountsStandard()) {
            SpeziInjector()
            StudyManager()
            HealthKit {
                // ???
            }
            Scheduler()
            Notifications()
        }
    }
}


/// Internal helper module which allows us to access the shared `Spezi` instance via `@Environment(Spezi.self)`.
@Observable
@MainActor
private final class SpeziInjector: Module, EnvironmentAccessible {
    private struct InjectionModifier: ViewModifier {
        @Environment(SpeziInjector.self)
        private var speziInjector
        
        func body(content: Content) -> some View {
            content.environment(speziInjector.spezi)
        }
    }
    
    @ObservationIgnored @Application(\.spezi) private var spezi
    @ObservationIgnored @Modifier private var speziInjector = InjectionModifier()
}
