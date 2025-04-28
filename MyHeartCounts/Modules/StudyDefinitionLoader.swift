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
        case noLastUsedRegion
        case unsupportedRegion(Locale.Region)
    }
    
    static let shared = StudyDefinitionLoader()
    
    private let logger = Logger(subsystem: "edu.stanford.MHC.studyLoader", category: "")
    // SAFETY: this is only mutated from the MainActor.
    nonisolated(unsafe) private(set) var studyDefinition: Result<StudyDefinition, LoadError>?
    
    private init() {
        Task {
            _ = try? await update()
        }
    }
    
    
    @discardableResult
    func load(for region: Locale.Region) async throws(LoadError) -> StudyDefinition {
        guard let url = Self.studyDefinitionUrl(for: region) else {
            throw .unsupportedRegion(region)
        }
        logger.debug("Fetching study definition for locale \(region.debugDescription)")
        let retval: Result<StudyDefinition, LoadError>
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
        switch LocalPreferencesStore.shared[.lastUsedFirebaseConfig] {
        case nil:
            throw .noLastUsedRegion
        case .region(let region), .custom(plistNameInBundle: _, let region):
            return try await load(for: region)
        }
    }
}


extension StudyDefinitionLoader {
    static func studyDefinitionUrl(for region: Locale.Region) -> URL? {
        switch region {
        case .unitedStates:
            "https://firebasestorage.googleapis.com/v0/b/myheart-counts-development.firebasestorage.app/o/public%2FmhcStudyDefinition_US.json?alt=media"
        case .unitedKingdom:
            "https://firebasestorage.googleapis.com/v0/b/myheart-counts-development.firebasestorage.app/o/public%2FmhcStudyDefinition_UK.json?alt=media"
        default:
            nil
        }
    }
}
