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
import OSLog
@_spi(APISupport) // we need to access `SpeziAppDelegate.spezi`
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
    fileprivate static let logger = Logger(subsystem: "edu.stanford.MyHeartCounts", category: "Config")
    
    enum LoadingError: Error {
        case unableToLoadFirebaseConfigPlist(underlying: (any Error)? = nil)
    }
    
    enum FirebaseConfigSelector {
        /// the firebase config for the last-used region should be loaded
        case lastUsedRegion
        /// the firebase config for the specified region should be loaded
        case specific(Locale.Region)
        #if DEBUG
        /// the firebase config plist at the specified url should be loaded
        case custom(URL)
        #endif
    }
    
    // swiftlint:disable:next function_body_length
    private static func firebaseOptions(for configSelector: FirebaseConfigSelector) throws(LoadingError) -> FirebaseOptions? {
        #if TEST
        // in a test build, we always load the US config.
        return try firebaseOptions(for: .specific(.unitedStates))
        #endif
        #if DEBUG_LUKAS
        logger.notice("Loading custom plist")
        return FirebaseOptions(plistInBundle: "GoogleService-Info-US2")
        #endif
        // swiftlint:disable legacy_objc_type
        // FirebaseOptions is an NSDictionary-based API...
        let region: Locale.Region?
        switch configSelector {
        case .lastUsedRegion:
            region = LocalPreferencesStore.shared[.selectedFirebaseConfig]
        case .specific(let region2):
            region = region2
        #if DEBUG
        case .custom(let url):
            if let options = FirebaseOptions(contentsOfFile: url.path) {
                return options
            } else {
                throw .unableToLoadFirebaseConfigPlist(underlying: nil)
            }
        #endif
        }
        guard let bundlePlistUrl = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") else {
            // this should be practically unreachable...
            throw .unableToLoadFirebaseConfigPlist()
        }
        let combinedConfig: NSDictionary
        do {
            combinedConfig = try NSDictionary(contentsOf: bundlePlistUrl, error: ())
        } catch {
            throw .unableToLoadFirebaseConfigPlist(underlying: error)
        }
        let tmpUrl = URL.temporaryDirectory.appendingPathComponent("GoogleService-Info.tmp", conformingTo: .propertyList)
        defer {
            try? FileManager.default.removeItem(at: tmpUrl)
        }
        let key: String
        switch region {
        case .unitedStates:
            key = "US"
        case .unitedKingdom:
            key = "UK"
        default:
            return nil
        }
        guard let configDict = combinedConfig[key] as? NSDictionary else {
            throw .unableToLoadFirebaseConfigPlist()
        }
        do {
            try configDict.write(to: tmpUrl)
        } catch {
            throw .unableToLoadFirebaseConfigPlist(underlying: error)
        }
        return FirebaseOptions(contentsOfFile: tmpUrl.path)
        // swiftlint:enable legacy_objc_type
    }
    
    /// Constructs an Array of Spezi Modules for loading Firebase and the other related modules, configured based on the specified selector.
    ///
    /// Returns nil if there was an issue resolving the selector.
    @MainActor
    static func config(for configSelector: FirebaseConfigSelector) -> [any Module] {
        do {
            guard let firebaseOptions = try firebaseOptions(for: configSelector) else {
                logger.notice("FirebaseOptions fetch returned nil. Not initializing anything.")
                return []
            }
            return Array {
                ConfigureFirebaseApp(/*name: "My Heart Counts", */options: firebaseOptions)
                LoadFirebaseTracking()
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
        } catch {
            logger.error("""
                FirebaseOptions fetch threw an error. Not initializing anything.
                Error: \(error)
                """)
            return []
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
    @MainActor static var didLoadFirebase = false
    
    @MainActor // IDEA maybe rename this? (here and elsewhere (it's not just firebase any more))
    static func loadFirebase(for region: Locale.Region) {
        guard let spezi = SpeziAppDelegate.spezi else {
            fatalError("Spezi not loaded")
        }
        guard !didLoadFirebase else {
            DeferredConfigLoading.logger.error("Did already load firebase, now asked to do it again, for a potentially different config. Will skip.")
            return
        }
        spezi.loadFirebase(for: region)
    }
    
    @MainActor
    private func loadFirebase(for region: Locale.Region) {
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



private final class LoadFirebaseTracking: Module {
    func configure() {
        Spezi.didLoadFirebase = true
    }
}
