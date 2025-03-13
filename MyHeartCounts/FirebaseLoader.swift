//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import class FirebaseCore.FirebaseOptions
import class FirebaseFirestore.FirestoreSettings
import class FirebaseFirestore.MemoryCacheSettings
import Foundation
import Observation
import Spezi
import SpeziFoundation
import SpeziAccount
import SpeziFirebaseAccount
import SpeziFirebaseAccountStorage
import SpeziFirebaseStorage
import SpeziFirebaseConfiguration
import SpeziFirestore


extension LocalPreferenceKey {
    static var selectedFirebaseConfig: LocalPreferenceKey<String?> { .make("selectedFirebaseConfig", makeDefault: { nil })}
}


@MainActor
final class FirebaseLoader: Module, EnvironmentAccessible, Sendable {
    @Application(\.spezi)
    private var spezi
    
    @Application(\.logger)
    private var logger
    
    func configure() {
        DispatchQueue.main.async {
            self.loadFirebase(for: .unitedStates)
        }
//        switch LocalPreferencesStore.shared[.selectedFirebaseConfig] {
//        case nil:
//            break
//        case "us":
//            loadFirebase(for: .unitedStates)
//        case "uk":
//            loadFirebase(for: .unitedKingdom)
//        case .some(let value):
//            logger.error("Unknown value for selectedFirebaseConfig: \(value)")
//        }
    }
    
    func loadFirebase(for region: Locale.Region) {
        let firebaseOptions: FirebaseOptions
        switch region {
        case .unitedStates:
            firebaseOptions = FirebaseOptions(plistInBundle: "GoogleService-Info-US")
        case .unitedKingdom:
            firebaseOptions = FirebaseOptions(plistInBundle: "GoogleService-Info-UK")
        default:
            fatalError() // TODO
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
            spezi.loadModule(module)
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
        self.init(contentsOfFile: path)!
//        guard let options = self.init(contentsOfFile: path) else {
//            preconditionFailure("Unable to create \(Self.self) from plist at \(path)")
//        }
    }
    
//    convenience init(
//        clientId: String,
//        reversedClientId: String,
//        gcmSenderId: String,
//        bundleId: String = Bundle.main.bundleIdentifier,
//        projectId: String,
//        storageBucket: String,
//        googleAppId: String
//    ) {
//        self.init(googleAppID: googleAppId, gcmSenderID: gcmSenderId)
//        self.clientID = clientId
////        self.reverseClientId = reversedClientId // TODO? what to do about this? it's a bit weird that there are 0 references to REVERSED_CLIENT_ID (the plist key) in the Firebase iOS SDK...
//        self.bundleID = bundleId
//        self.projectID = projectId
//        self.storageBucket = storageBucket
//    }
}


@Observable
@MainActor
final class TestModule: Module, EnvironmentAccessible, Sendable {
}
