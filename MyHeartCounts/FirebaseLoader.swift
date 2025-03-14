//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable type_contents_order

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


extension LocalPreferenceKey {
    static var selectedFirebaseConfig: LocalPreferenceKey<String?> {
        .make("selectedFirebaseConfig", makeDefault: { nil })
    }
}


extension Spezi {
    @MainActor
    static func loadFirebase(for region: Locale.Region) {
        guard let spezi = SpeziAppDelegate.spezi else {
            fatalError("Spezi not loaded")
        }
        spezi.loadFirebase(for: region)
    }
    
    @MainActor
    func loadLastUsedFirebaseConfigIfPossible() {
        switch LocalPreferencesStore.shared[.selectedFirebaseConfig] {
        case nil:
            break
        case "us":
            loadFirebase(for: .unitedStates)
        case "uk":
            loadFirebase(for: .unitedKingdom)
        case .some(let value):
            logger.error("Unknown value for selectedFirebaseConfig: \(value)")
        }
    }
    
    @MainActor
    func loadFirebase(for region: Locale.Region) {
        let firebaseOptions: FirebaseOptions
        switch region {
        case .unitedStates:
            firebaseOptions = FirebaseOptions(plistInBundle: "GoogleService-Info-US")
        case .unitedKingdom:
            firebaseOptions = FirebaseOptions(plistInBundle: "GoogleService-Info-UK")
        default:
            logger.error("Invalid region. Not loading firebase.")
            return
        }
        let modules: [any Module] = Array {
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
        }
        for module in modules {
            self.loadModule(module)
        }
    }
    
    
    private var accountEmulator: (host: String, port: Int)? {
        if FeatureFlags.useFirebaseEmulator {
            (host: "localhost", port: 9099)
        } else {
            nil
        }
    }
    
    
    private var firestore: Firestore {
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


extension FirebaseOptions {
    convenience init(plistInBundle filename: String) {
        guard let path = Bundle.main.path(forResource: filename, ofType: "plist") else {
            preconditionFailure("Unable to find '\(filename).plist' in bundle")
        }
        self.init(contentsOfFile: path)! // swiftlint:disable:this force_unwrapping
    }
}
