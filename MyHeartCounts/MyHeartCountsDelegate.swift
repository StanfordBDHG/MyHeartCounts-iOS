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
//import FirebaseCore
//import SpeziAccount
//import SpeziFirebaseAccount
//import SpeziFirebaseAccountStorage
//import SpeziFirestore
//import SpeziFirebaseStorage


@Observable
class MyHeartCountsDelegate: SpeziAppDelegate { // swiftlint:disable:this file_types_order
    override var configuration: Configuration {
        Configuration(standard: MyHeartCountsStandard()) {
            SpeziInjector()
////            if let region = LocalPreferencesStore.shared[.selectedFirebaseConfig] {
////                FirebaseLoader(region: region)
////            }
////            FirebaseLoader(region: .unitedStates)
//            StudyManager()
////            let firebaseOptions = FirebaseOptions(plistInBundle: "GoogleService-Info-US")
////            ConfigureFirebaseApp(/*name: "My Heart Counts", */options: firebaseOptions)
////            AccountConfiguration(
////                service: FirebaseAccountService(providers: [.emailAndPassword, .signInWithApple], emulatorSettings: nil),
////                storageProvider: FirestoreAccountStorage(storeIn: FirebaseConfiguration.userCollection),
////                configuration: [
////                    .requires(\.userId),
////                    .requires(\.name),
////                    // additional values stored using the `FirestoreAccountStorage` within our Standard implementation
////                    .collects(\.genderIdentity),
////                    .collects(\.dateOfBirth)
////                ]
////            )
////            Firestore()
////            FirebaseStorageConfiguration()
            
            DeferredConfigLoading.config(for: .lastUsed)
            
            HealthKit {
                // ???
            }
            Scheduler()
            Notifications()
        }
    }
    
    override func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let prefs = LocalPreferencesStore.shared
        if FeatureFlags.showOnboarding {
            prefs[.onboardingFlowComplete] = false
            prefs[.selectedFirebaseConfig] = nil
        }
        if FeatureFlags.skipOnboarding {
            prefs[.onboardingFlowComplete] = true
        }
//        let FM = FileManager.default
//        let url = URL.documentsDirectory.appending(path: "edu.stanford.spezi.scheduler.storage.sqliteeee")
//        try! "Hello World".write(to: url, atomically: true, encoding: .utf8) // swiftlint:disable:this force_try
//        print(try? String(contentsOf: url, encoding: .utf8))
        // NOTE: we're intentionally calling super at the end here.
        return super.application(application, willFinishLaunchingWithOptions: launchOptions)
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


extension ModuleBuilder {
    static func buildExpression(_ modules: some Sequence<any Module>) -> [any Module] {
        Array(modules)
    }
}
