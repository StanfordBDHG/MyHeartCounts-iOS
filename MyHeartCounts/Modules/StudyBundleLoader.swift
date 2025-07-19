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
final class StudyBundleLoader: Module, Sendable {
    enum LoadError: Error {
        case unableToFetchFromServer(any Error)
        case unableToDecode(any Error)
        case noLastUsedFirebaseConfig
    }
    
    static let shared = StudyBundleLoader()
    
    private let logger = Logger(subsystem: "edu.stanford.MHC.studyLoader", category: "")
    
    /// The currently active Study Bundle loading operation, if any.
    ///
    /// This exists to avoid performing multiple, concurrent downloads of the bundle.
    ///
    /// - Note: we use the Result in here, and set the Task's Failure type to Never, since Task currently only supports type-erased `any Error` failures.
    ///     (and does not support typed throws in its init, for whatever reason...)
    @ObservationIgnored @MainActor private var loadStudyBundleTask: Task<Result<StudyBundle, LoadError>, Never>?
    
    // SAFETY: this is only mutated from the MainActor.
    // NOTE: the compiler thinks the nonisolated(unsafe) isn't needed here. this is a lie. see also https://github.com/swiftlang/swift/issues/81962
    /// The result of the most recent Study Bundle download operation.
    nonisolated(unsafe) private(set) var studyBundle: Result<StudyBundle, LoadError>?
    
    // SAFETY: the FileManager type itself is not thread safe,
    // but we have our own instance (as opposed to using `FileManager.default`), and we never mutate it.
    nonisolated(unsafe) private let fileManager = FileManager()
    
    /// The url where we store the `StudyBundle`s downloaded by the Loader.
    ///
    /// Note that this is distinct from what the `StudyManager`' does, which also stores the `StudyBundle`s of the studie(s) we're enrolled into, in a special directory.
    private let studyBundlesUrl: URL
    
    private init() {
        studyBundlesUrl = URL.documentsDirectory.appending(path: "MHC/StudyBundlesCache", directoryHint: .isDirectory)
        Task {
            _ = try? await update()
        }
        Task(priority: .background) {
            try? await cleanupOldStudyBundles()
        }
    }
    
    
    @discardableResult
    @MainActor
    func update() async throws(LoadError) -> StudyBundle {
        if let loadStudyBundleTask {
            // we need to do `.result.get()` here, instead of a simple `.value`, since the throw in the later case isn't typed.
            return try await loadStudyBundleTask.result.get().get()
        }
        if let selector = FeatureFlags.overrideFirebaseConfig ?? LocalPreferencesStore.standard[.lastUsedFirebaseConfig],
           let firebaseOptions = try? DeferredConfigLoading.firebaseOptions(for: selector),
           let storageBucket = firebaseOptions.storageBucket {
            logger.notice("Attempting to load study definition from firebase storage bucket '\(storageBucket)'")
            let task = Task<Result<StudyBundle, LoadError>, Never> {
                let result: Result<StudyBundle, LoadError>
                do {
                    result = .success(try await load(fromBucket: storageBucket))
                } catch let error as LoadError {
                    result = .failure(error)
                } catch {
                    // unresachable, but swiftc doesn't seem to understand.
                    result = .failure(.unableToFetchFromServer(error))
                }
                await MainActor.run {
                    self.studyBundle = result
                    self.loadStudyBundleTask = nil
                }
                return result
            }
            self.loadStudyBundleTask = task
            return try await task.result.get().get()
        } else {
            logger.error("No last-used firebase config")
            throw .noLastUsedFirebaseConfig
        }
    }
    
    
    @discardableResult
    private func load(fromBucket bucketName: String) async throws(LoadError) -> StudyBundle {
        let downloadUrl: URL
        do {
            if let url = LaunchOptions.launchOptions[.overrideStudyBundleLocation] {
                downloadUrl = try await download(url)
            } else {
                downloadUrl = try await download(
                    fileName: "mhcStudyBundle.\(StudyBundle.fileExtension).aar",
                    inBucket: bucketName
                )
            }
        } catch {
            throw .unableToFetchFromServer(error)
        }
        let tmpUrl = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("\(StudyBundle.fileExtension).aar")
        let dstUrl = self.studyBundlesUrl.appendingPathComponent(UUID().uuidString, conformingTo: .speziStudyBundle)
        do {
            try fileManager.copyItem(at: downloadUrl, to: tmpUrl, overwriteExisting: true)
            defer {
                try? fileManager.removeItem(at: tmpUrl)
            }
            try fileManager.unarchiveDirectory(at: tmpUrl, to: dstUrl)
            return try StudyBundle(bundleUrl: dstUrl)
        } catch {
            fatalError("\(error)")
        }
    }
    
    
    /// Downloads the file with the specified `filename` from the Firebase Storage bucket `bucketName`
    @discardableResult
    private func download(fileName: String, inBucket bucketName: String) async throws -> URL {
        try await download(Self.url(ofFile: fileName, inBucket: bucketName))
    }
    
    @discardableResult
    private func download(_ url: URL) async throws -> URL {
        logger.notice("will try to download '\(url.absoluteString)'")
        let session = URLSession(configuration: .ephemeral)
        let (downloadUrl, response) = try await session.download(from: url)
        logger.notice("did finish download of '\(url.lastPathComponent)'")
        guard let response = response as? HTTPURLResponse else {
            throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to decode HTTP response"
            ])
        }
        switch response.statusCode {
        case 200:
            return downloadUrl
        case 404:
            throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to find file '\(url)'"
            ])
        default:
            throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to fetch file '\(url)'"
            ])
        }
    }
    
    private func cleanupOldStudyBundles() async throws {
        struct Entry {
            let url: URL
            let creationDate: Date
            init?(url: URL) {
                guard let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate else {
                    return nil
                }
                self.url = url
                self.creationDate = creationDate
            }
        }
        
        let entries = try fileManager
            .contents(of: studyBundlesUrl, includingPropertiesForKeys: [.creationDateKey])
            .compactMap { Entry(url: $0) }
            .sorted(using: KeyPathComparator(\.creationDate))
        for entry in entries.dropLast() {
            try fileManager.removeItem(at: entry.url)
        }
    }
}


extension StudyBundleLoader {
    private static func url(ofFile filename: String, inBucket bucketName: String) -> URL {
        "https://firebasestorage.googleapis.com/v0/b/\(bucketName)/o/public%2F\(filename)?alt=media"
    }
}
