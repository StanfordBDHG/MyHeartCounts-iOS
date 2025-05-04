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
    static var lastUsedFirebaseConfig: LocalPreferenceKey<DeferredConfigLoading.FirebaseConfigSelector?> {
        .make("lastUsedFirebaseConfig", default: nil)
    }
}


enum DeferredConfigLoading {
    fileprivate static let logger = Logger(subsystem: "edu.stanford.MyHeartCounts", category: "Config")
    
    enum LoadingError: Error {
        case unableToLoadFirebaseConfigPlist(underlying: (any Error)? = nil)
    }
    
    enum FirebaseConfigSelector: Codable, LaunchOptionDecodable {
        /// the firebase config for the specified region should be loaded
        case region(Locale.Region)
        /// the firebase config plist with the specified name should be loaded from the main bundle
        case custom(plistNameInBundle: String)
        /// the firebase config plist at the specified URL should be loaded
        case customUrl(URL)
        
        /// Decodes a `FirebaseConfigSelector` from a launch option value
        ///
        /// `--firebaseConfig region=US`
        /// `--firebaseConfig plist=GoogleService-Info_UK.plist`
        /// `--firebaseConfig plist=/Users/lukas/Desktop/MHC.plist`
        /// `--firebaseConfig plist=https://mhc.spezi.stanford.edu/config.plist`
        init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
            try context.assertNumRawArgs(.equal(1))
            let components = context.rawArgs[0].split(separator: "=")
            guard components.count == 2 else {
                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: context.rawArgs[0])
            }
            switch components[0] {
            case "region":
                let regionIdentifier = String(components[1])
                guard Locale.Region.isoRegions.contains(where: { $0.identifier == regionIdentifier }) else {
                    throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: context.rawArgs[0])
                }
                self = .region(Locale.Region(regionIdentifier))
            case "plist":
                let location = String(components[1])
                if location.starts(with: "https://") {
                    // https --> treat as internet url (which isn't allowed)
                    throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: context.rawArgs[0])
                } else if location.starts(with: "/") {
                    // / --> treat as local file system url
                    self = .customUrl(URL(filePath: location))
                } else {
                    // location is not a URL and not an absolute path --> treat it as a plist in the bundle
                    self = .custom(plistNameInBundle: location)
                }
            default:
                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: context.rawArgs[0])
            }
        }
    }
    
    
    static func firebaseOptions(for configSelector: FirebaseConfigSelector) throws(LoadingError) -> FirebaseOptions? {
        if let overrideSelector = FeatureFlags.overrideFirebaseConfig {
            try _firebaseOptions(for: overrideSelector)
        } else {
            try _firebaseOptions(for: configSelector)
        }
    }
    
    
    // swiftlint:disable:next cyclomatic_complexity
    private static func _firebaseOptions(for configSelector: FirebaseConfigSelector) throws(LoadingError) -> FirebaseOptions? {
        logger.notice("[\(#function)] selector: \(String(describing: configSelector))")
        // swiftlint:disable legacy_objc_type
        // FirebaseOptions is an NSDictionary-based API...
        switch configSelector {
        case .region(let region):
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
                logger.error("[\(#function)] invalid region input '\(region.identifier)'. returning nil")
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
            logger.notice("[\(#function)] returning config for '\(region.identifier)' in local GoogleService-Info.plist file")
            return FirebaseOptions(contentsOfFile: tmpUrl.path)
        case .custom(let plistNameInBundle):
            guard let bundlePlistUrl = Bundle.main.url(forResource: plistNameInBundle, withExtension: "plist") else {
                logger.error("[\(#function)] unable to find '\(plistNameInBundle).plist' in bundle. returning nil")
                return nil
            }
            logger.notice("[\(#function)] returning config for '\(plistNameInBundle).plist' in bundle")
            return FirebaseOptions(contentsOfFile: bundlePlistUrl.path)
        case .customUrl(let url):
            guard url.isFileURL else {
                preconditionFailure("Only file urls are supported when loading external firebase configs!")
            }
            logger.notice("[\(#function)] returning config for plist at '\(url.path)'")
            return FirebaseOptions(contentsOfFile: url.path)
        }
        // swiftlint:enable legacy_objc_type
    }
    
    
    @MainActor static var initialAppLaunchConfig: [any Module] {
        if FeatureFlags.disableFirebase {
            baseModules
        } else if let selector = FeatureFlags.overrideFirebaseConfig {
            config(for: selector)
        } else {
            switch LocalPreferencesStore.standard[.lastUsedFirebaseConfig] {
            case .none:
                []
            case .some(let selector):
                config(for: selector)
            }
        }
    }
    
    /// The set of modules which we always want to load, regardless of whether Firebase is enabled or disabled.
    @MainActor @ArrayBuilder<any Module> private static var baseModules: [any Module] {
        StudyManager()
        NotificationsManager()
    }
    
    /// Constructs an Array of Spezi Modules for loading Firebase and the other related modules, configured based on the specified selector.
    ///
    /// Returns nil if there was an issue resolving the selector.
    @MainActor
    static func config(for configSelector: FirebaseConfigSelector) -> [any Module] {
        logger.notice("CLI args: \(CommandLine.arguments)")
        guard !FeatureFlags.disableFirebase else {
            return baseModules
        }
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
                baseModules
                NewsManager()
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
        let config = DeferredConfigLoading.config(for: .region(region))
        guard !config.isEmpty else {
            return
        }
        for module in config {
            self.loadModule(module)
        }
        LocalPreferencesStore.standard[.lastUsedFirebaseConfig] = .region(region)
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
    @Dependency(StudyDefinitionLoader.self)
    private var studyLoader
    
    func configure() {
        Spezi.didLoadFirebase = true
        Task {
            try await studyLoader.update()
        }
    }
}
