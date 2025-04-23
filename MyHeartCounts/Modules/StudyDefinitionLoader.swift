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
    }
    
    static let studyDefinitionUrl: URL = "https://firebasestorage.googleapis.com/v0/b/myheart-counts-development.firebasestorage.app/o/public%2FmhcStudyDefinition.json?alt=media"
    
    static let shared = StudyDefinitionLoader()
    
    private let logger = Logger(subsystem: "edu.stanford.MHC.studyLoader", category: "")
    // SAFETY: this is only mutated from the MainActor.
    nonisolated(unsafe) private(set) var studyDefinition: Result<StudyDefinition, LoadError>?
    
    private init() {
        Task {
            try await reload()
        }
    }
    
    @discardableResult
    func reload() async throws(LoadError) -> StudyDefinition {
        let retval: Result<StudyDefinition, LoadError>
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.studyDefinitionUrl)
            do {
                let definition = try JSONDecoder().decode(StudyDefinition.self, from: data, configuration: .init(allowTrivialSchemaMigrations: true))
                retval = .success(definition)
                logger.notice("Successfully loaded study definition: '\(definition.metadata.title)' @ revision \(definition.studyRevision)")
            } catch {
                retval = .failure(.unableToDecode(error))
                logger.error("Failed to decode study revision: \(error)")
            }
        } catch {
            retval = .failure(.unableToFetchFromServer(error))
            logger.error("Failed to fetch study revision: \(error)")
        }
        Task { @MainActor in
            self.studyDefinition = retval
        }
        return try retval.get()
    }
}
