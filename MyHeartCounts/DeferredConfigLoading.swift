//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable type_contents_order file_types_order

import class FirebaseCore.FirebaseOptions
import class FirebaseFirestore.FirestoreSettings
import class FirebaseFirestore.MemoryCacheSettings
import Foundation
import Observation
@_spi(APISupport)
import Spezi
import SpeziAccount
import SpeziFirebaseAccount
import SpeziFirebaseAccountStorage
import SpeziFirebaseConfiguration
import SpeziFirebaseStorage
import SpeziFirestore
import SpeziFoundation
import SpeziStudy
import SwiftUI


extension LocalPreferenceKey {
    static var selectedFirebaseConfig: LocalPreferenceKey<Locale.Region?> {
        .make("selectedFirebaseConfig", makeDefault: { nil })
    }
}


enum DeferredConfigLoading {
    enum FirebaseRegionSelector {
        case lastUsed
        case specific(Locale.Region)
    }
    
    private static func firebaseOptions(for regionSelector: FirebaseRegionSelector) -> FirebaseOptions? {
        let region: Locale.Region?
        switch regionSelector {
        case .lastUsed:
            region = LocalPreferencesStore.shared[.selectedFirebaseConfig]
        case .specific(let region2):
            region = region2
        }
        #if DEBUG_LUKAS
        if region != nil {
            return FirebaseOptions(plistInBundle: "GoogleService-Info-US2")
        }
        #endif
        switch region {
        case .unitedStates:
            return FirebaseOptions(plistInBundle: "GoogleService-Info-US")
        case .unitedKingdom:
            return FirebaseOptions(plistInBundle: "GoogleService-Info-UK")
        default:
            return nil
        }
    }
    
    @MainActor
    @ArrayBuilder<any Module>
    static func config(for regionSelector: FirebaseRegionSelector) -> [any Module] {
        if let firebaseOptions = firebaseOptions(for: regionSelector) {
            ConfigureFirebaseApp(/*name: "My Heart Counts", */options: firebaseOptions)
            AccountConfiguration(
                service: FirebaseAccountService(providers: [.emailAndPassword, .signInWithApple], emulatorSettings: accountEmulator),
                storageProvider: FirestoreAccountStorage(storeIn: FirebaseConfiguration.userCollection),
                configuration: [
                    .requires(\.userId),
                    .requires(\.name),
                    // additional values stored using the `FirestoreAccountStorage` within our Standard implementation
                    .collects(\.genderIdentity),
                    .collects(\.dateOfBirth)
                ]
            )
            firestore
            if FeatureFlags.useFirebaseEmulator {
                FirebaseStorageConfiguration(emulatorSettings: (host: "localhost", port: 9199))
            } else {
                FirebaseStorageConfiguration()
            }
            StudyManager()
        }
    }
    
    private static var accountEmulator: (host: String, port: Int)? {
        if FeatureFlags.useFirebaseEmulator {
            (host: "localhost", port: 9099)
        } else {
            nil
        }
    }
    
    
    private static var firestore: Firestore {
        let settings = FirestoreSettings()
        if FeatureFlags.useFirebaseEmulator {
            settings.host = "localhost:8080"
            settings.cacheSettings = MemoryCacheSettings()
            settings.isSSLEnabled = false
        }
        return Firestore(
            settings: settings
        )
    }
}


extension Spezi {
    @MainActor // TODO rename (here and elsewhere (it's not just firebase any more))
    static func loadFirebase(for region: Locale.Region) {
        guard let spezi = SpeziAppDelegate.spezi else {
            fatalError("Spezi not loaded")
        }
        spezi.loadFirebase(for: region)
    }
    
    @MainActor
    func loadFirebase(for region: Locale.Region) {
        let config = DeferredConfigLoading.config(for: .specific(region))
        guard !config.isEmpty else {
            return
        }
        for module in config {
            self.loadModule(module)
        }
        LocalPreferencesStore.shared[.selectedFirebaseConfig] = region
    }
}


extension FirebaseOptions {
    convenience init(plistInBundle filename: String) {
        guard let path = Bundle.main.path(forResource: filename, ofType: "plist") else {
            preconditionFailure("Unable to find '\(filename).plist' in bundle")
        }
        self.init(contentsOfFile: path)! // swiftlint:disable:this force_unwrapping
    }
}
