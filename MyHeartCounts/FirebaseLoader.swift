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
import SpeziStudy
import SwiftUI


extension LocalPreferenceKey {
    static var selectedFirebaseConfig: LocalPreferenceKey<Locale.Region?> {
        .make("selectedFirebaseConfig", makeDefault: { nil })
    }
}


final class FirebaseLoader: Module {
    @Application(\.spezi)
    private var spezi
    
    private let region: Locale.Region
    
    init(region: Locale.Region) {
        self.region = region
    }
    
    func configure() {
        DispatchQueue.main.async {
            self.spezi.loadFirebase(for: self.region)
        }
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
    func loadLastUsedFirebaseConfigIfPossible() {
        switch LocalPreferencesStore.shared[.selectedFirebaseConfig] {
        case nil:
            break
        case .some(let region) where region == .unitedStates || region == .unitedKingdom:
            loadFirebase(for: region)
        case .some(let region):
            logger.error("Invalid region for selectedFirebaseConfig: \(region.debugDescription)")
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
        LocalPreferencesStore.shared[.selectedFirebaseConfig] = region
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


//private struct LoadFirebaseModifier: ViewModifier {
//    @Environment(Spezi.self)
//    private var spezi
//    
//    @State private var didRun = false
//    
//    func body(content: Content) -> some View {
//        if didRun {
//            content
//        } else {
//            content
//                .onAppear {
//                    didRun = true
//                    print("WILL CONFIGURE FIREBASE")
//                    spezi.loadLastUsedFirebaseConfigIfPossible()
//                }
//        }
//    }
//}
//
//extension View {
//    func loadingLastUsedFirebaseConfigIfPossible() -> some View {
//        self.modifier(LoadFirebaseModifier())
//    }
//}
