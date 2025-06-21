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
    
    // SAFETY: this is only mutated from the MainActor.
    // NOTE: the compiler thinks the nonisolated(unsafe) isn't needed here. this is a lie. see also https://github.com/swiftlang/swift/issues/81962
    nonisolated(unsafe) private(set) var consentDocument: Result<String, LoadError>?
    
    private init() {
        Task {
            _ = try? await update()
        }
    }
    
    
    @discardableResult
    func load(fromBucket bucketName: String) async throws(LoadError) -> StudyDefinition {
        try await load(filename: "mhcStudyDefinition.json", inBucket: bucketName, storeTo: \StudyDefinitionLoader.studyDefinition) { data in
            try JSONDecoder().decode(StudyDefinition.self, from: data, configuration: .init(allowTrivialSchemaMigrations: true))
        }
    }
    
    @discardableResult
    func update() async throws(LoadError) -> StudyDefinition {
        if let selector = FeatureFlags.overrideFirebaseConfig ?? LocalPreferencesStore.standard[.lastUsedFirebaseConfig],
           let firebaseOptions = try? DeferredConfigLoading.firebaseOptions(for: selector),
           let storageBucket = firebaseOptions.storageBucket {
            logger.notice("Attempting to load study definition from firebase storage bucket '\(storageBucket)'")
            let studyDefinition = try await load(fromBucket: storageBucket)
            _ = try? await loadConsent(fromBucket: storageBucket)
            return studyDefinition
        } else {
            logger.error("No last-used firebase config")
            throw .noLastUsedFirebaseConfig
        }
    }
    
    func loadConsent(fromBucket bucketName: String) async throws(LoadError) -> String {
        try await load(filename: "Consent_en-US.md", inBucket: bucketName, storeTo: \StudyDefinitionLoader.consentDocument) { data in
            if let string = String(data: data, encoding: .utf8) {
                return string
            } else {
                throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Consent Text isn't UTF-8"
                ])
            }
        }
    }
    
    
    @discardableResult
    private func load<T: Sendable>(
        filename: String,
        inBucket: String,
        storeTo dstKeyPath: (ReferenceWritableKeyPath<StudyDefinitionLoader, Result<T, LoadError>?> & Sendable)? = nil,
        decode: (Data) throws -> T
    ) async throws(LoadError) -> T {
        let url = Self.url(ofFile: filename, inBucket: inBucket)
        logger.notice("will try to load from url '\(url.absoluteString)'")
        let retval: Result<T, LoadError>
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
                    let value = try decode(data)
                    retval = .success(value)
                } catch {
                    retval = .failure(.unableToDecode(error))
                }
            case 404:
                throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to find file '\(filename)' in bucket'\(inBucket)'"
                ])
            default:
                throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to fetch file '\(filename)' in bucket'\(inBucket)'"
                ])
            }
        } catch {
            retval = .failure(.unableToFetchFromServer(error))
        }
        if let dstKeyPath {
            Task { @MainActor in
                self[keyPath: dstKeyPath] = retval
            }
        }
        return try retval.get()
    }
}


extension StudyDefinitionLoader {
    private static func studyLocation(inBucket bucketName: String) -> URL {
        if let url = LaunchOptions.launchOptions[.overrideStudyDefinitionLocation] {
            url
        } else {
            url(ofFile: "mhcStudyDefinition.json", inBucket: bucketName)
        }
    }
    
    private static func url(ofFile filename: String, inBucket bucketName: String) -> URL {
        "https://firebasestorage.googleapis.com/v0/b/\(bucketName)/o/public%2F\(filename)?alt=media"
    }
}
