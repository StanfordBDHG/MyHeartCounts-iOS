//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SpeziStudyDefinition


@Observable
final class StudyDefinitionLoader: Module, Sendable {
    enum LoadError: Error {
        case unableToFetchFromServer(any Error)
        case unableToDecode(any Error)
        case noLastUsedFirebaseConfig
    }
    
    static let shared = StudyDefinitionLoader()
    
    private let logger = Logger(subsystem: "edu.stanford.MHC.studyLoader", category: "")
    // SAFETY: this is only mutated from the MainActor.
    // NOTE: the compiler thinks the nonisolated(unsafe) isn't needed here. this is a lie. see also https://github.com/swiftlang/swift/issues/81962
    nonisolated(unsafe) private(set) var studyDefinition: Result<StudyDefinition, LoadError>?
    
    private init() {
        Task {
            _ = try await update()
        }
    }
    
    
    @discardableResult
    func load(fromBucket bucketName: String) async throws(LoadError) -> StudyDefinition {
        let url = Self.studyLocation(inBucket: bucketName)
        logger.debug("Fetching study definition from bucket '\(bucketName)'")
        logger.debug("Fetching study definition from '\(url.absoluteString)'")
        let retval: Result<StudyDefinition, LoadError>
        do {
            let session = URLSession(configuration: .ephemeral)
            let (data, response) = try await session.data(from: url)
            guard let response = response as? HTTPURLResponse else {
                throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to decode HTTP response"
                ])
            }
            switch response.statusCode {
            case 200:
                do {
                    let definition = try JSONDecoder().decode(
                        StudyDefinition.self,
                        from: data,
                        configuration: .init(allowTrivialSchemaMigrations: true)
                    )
                    retval = .success(definition)
                    logger.notice("Successfully loaded study definition: '\(definition.metadata.title)' @ revision \(definition.studyRevision)")
                } catch {
                    retval = .failure(.unableToDecode(error))
                    logger.error("Failed to decode study revision: \(error) from input '\(String(data: data, encoding: .utf8) ?? "<nil>")'")
                }
            case 404:
                throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to find the Study Definition"
                ])
            default:
                throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to fetch the Study Definition"
                ])
            }
        } catch {
            retval = .failure(.unableToFetchFromServer(error))
            logger.error("Failed to fetch study definjtion: \(error)")
        }
        Task { @MainActor in
            self.studyDefinition = retval
        }
        return try retval.get()
    }
    
    @discardableResult
    func update() async throws(LoadError) -> StudyDefinition {
        if let selector = FeatureFlags.overrideFirebaseConfig ?? LocalPreferencesStore.standard[.lastUsedFirebaseConfig],
           let firebaseOptions = try? DeferredConfigLoading.firebaseOptions(for: selector),
           let storageBucket = firebaseOptions.storageBucket {
            logger.notice("Attempting to load study definition from firebase storage bucket '\(storageBucket)'")
            return try await load(fromBucket: storageBucket)
        } else {
            logger.error("No last-used firebase config")
            throw .noLastUsedFirebaseConfig
        }
    }
}


extension StudyDefinitionLoader {
    private static func studyLocation(inBucket bucketName: String) -> URL {
        if let url = LaunchOptions.launchOptions[.overrideStudyDefinitionLocation] {
            url
        } else {
            "https://firebasestorage.googleapis.com/v0/b/\(bucketName)/o/public%2FmhcStudyDefinition.json?alt=media"
        }
    }
}
