//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import FirebaseFirestore
import Foundation
import HealthKit
import HealthKitOnFHIR
@preconcurrency import ModelsR4
import SpeziFoundation
import SpeziHealthKit
import UserNotifications


extension LocalPreferenceKey {
    static var sendHealthSampleUploadNotifications: LocalPreferenceKey<Bool> {
        .make("sendHealthSampleUploadNotifications", default: false)
    }
    
    /// the last-seen value of the ``SpeziAccount/AccountDetails/enableDebugMode`` account key value.
    ///
    /// we need this to be able to access the account key value immediately after launch,
    /// where it typically isn't yet available if the account details haven't yet been delivered to the Standard.
    static var lastSeenIsDebugModeEnabledAccountKey: LocalPreferenceKey<Bool> {
        .make("lastSeenIsDebugModeEnabledAccountKey", default: false)
    }
}


extension MyHeartCountsStandard: HealthKitConstraint {
    private var enableNotifications: Bool {
        true
//        let prefs = LocalPreferencesStore.standard
//        return prefs[.lastSeenIsDebugModeEnabledAccountKey] && prefs[.sendHealthSampleUploadNotifications]
    }
    
    func handleNewSamples<Sample>(_ addedSamples: some Collection<Sample>, ofType sampleType: SampleType<Sample>) async {
        do {
            try await uploadHealthObservations(addedSamples, batchSize: 100)
        } catch {
            logger.error("Error uploading HealthKit samples: \(error)")
        }
    }
    
    
    func handleDeletedObjects<Sample>(_ deletedObjects: some Collection<HKDeletedObject>, ofType sampleType: SampleType<Sample>) async {
        logger.notice("\(#function) \(deletedObjects.count) deleted HKObjects for \(sampleType.displayTitle)")
        let triggerDidUploadNotification = await showDebugWillUploadHealthDataUploadEventNotification(
            for: .deleted(sampleTypeTitle: sampleType.displayTitle, count: deletedObjects.count)
        )
        let logger = logger
        for object in deletedObjects {
            do {
                let doc = try await healthObservationDocument(forSampleType: sampleType.hkSampleType.identifier, id: object.uuid)
                let deleteDoc = { @Sendable in
                    await self.logger.notice("Deleting document for now-deleted HKObject (id: \(object.uuid); sampleType: \(sampleType.displayTitle))")
                    try await doc.delete()
                }
                do {
                    let resourceProxy: ResourceProxy
                    do {
                        resourceProxy = try await doc.getDocument(as: ResourceProxy.self)
                    } catch {
                        logger.error("Unable to decode ResourceProxy: \(error). Deleting instead, as fallback.")
                        try await deleteDoc()
                        continue
                    }
                    if let observation = resourceProxy.get(if: Observation.self) {
                        // For Observation-backed Health samples (which should be all of them),
                        // we intentionally don't delete the doc when the sample gets deleted from HealthKit,
                        // but rather set the Observation's ststus to `.enteredInError`,
                        // which indicates a previously published but now withdrawn value.
                        logger.notice("Updating status of FHIR Observation created from now-deleted HKObject to enteredInError (id: \(object.uuid))")
                        observation.status = .init(.enteredInError)
                        try await doc.setData(from: resourceProxy)
                    } else {
                        logger.error("ResourceProxy isn't an Observation (found a \(type(of: resourceProxy.get())). Deleting instead, as fallback.")
                        try await deleteDoc()
                        continue
                    }
                }
            } catch {
                logger.error("Error saving HealthKit sample to Firebase: \(error)")
                // (probably not needed, since firebase already seems to be doing this for us...)
            }
        }
        await triggerDidUploadNotification()
    }
}


extension MyHeartCountsStandard {
    func uploadHealthObservation(_ observation: some HealthObservation & Sendable) async throws {
        try await uploadHealthObservations(CollectionOfOne(observation), batchSize: 1)
    }
    
    func uploadHealthObservations(
        _ observations: consuming some Collection<some HealthObservation & Sendable>,
        batchSize: Int = 100
    ) async throws {
        guard !observations.isEmpty, let sampleTypeIdentifier = observations.first?.sampleTypeIdentifier else {
            return
        }
        let issuedDate = FHIRPrimitive<ModelsR4.Instant>(try .init(date: .now))
        if observations.count >= 100 && observations.allSatisfy({ $0.sampleTypeIdentifier == sampleTypeIdentifier }) {
            let numObservations = observations.count
            logger.notice("Uploading \(numObservations) observations of type '\(sampleTypeIdentifier)' via zlib upload")
            let triggerDidUploadNotification = await showDebugWillUploadHealthDataUploadEventNotification(
                for: .new(sampleTypeTitle: sampleTypeIdentifier, count: numObservations, uploadMode: .zlib)
            )
            let resources = try observations.map { observation in
                try observation.resource(withMapping: .default, issuedDate: issuedDate, extensions: [.sampleUploadTimeZone])
            }
            _ = consume observations
            let encoded = try JSONEncoder().encode(resources)
            let compressed = try encoded.compressed(using: Zlib.self)
            _ = consume encoded
            let url = URL.temporaryDirectory.appending(path: "\(sampleTypeIdentifier)_\(UUID().uuidString).json.zlib", directoryHint: .notDirectory)
            try compressed.write(to: url)
            _ = consume compressed
            _Concurrency.Task {
                try await healthDataUploader.upload(url, category: .liveData)
                await triggerDidUploadNotification()
            }
        } else {
            for chunk in observations.chunks(ofCount: batchSize) {
                let triggerDidUploadNotification = await showDebugWillUploadHealthDataUploadEventNotification(
                    for: .new(sampleTypeTitle: sampleTypeIdentifier, count: chunk.count, uploadMode: .direct)
                )
                let batch = Firestore.firestore().batch()
                for observation in chunk {
                    do {
                        let document = try await healthObservationDocument(for: observation)
                        let path = document.path
                        logger.notice("Uploading Health Observation to \(path)")
                        let resource = try observation.resource(
                            withMapping: .default,
                            issuedDate: issuedDate,
                            extensions: [.sampleUploadTimeZone]
                        )
                        try batch.setData(from: resource, forDocument: document)
                    } catch {
                        logger.error("Error saving health observation to Firebase: \(error); input: \(String(describing: observation))")
                    }
                }
                try await batch.commit()
                await triggerDidUploadNotification()
            }
        }
    }
    
    
    private func healthObservationDocument(for observation: some HealthObservation) async throws -> FirebaseFirestore.DocumentReference {
        try await healthObservationDocument(forSampleType: observation.sampleTypeIdentifier, id: observation.id)
    }
    
    private func healthObservationDocument(
        forSampleType sampleTypeIdentifier: String,
        id: UUID
    ) async throws -> FirebaseFirestore.DocumentReference {
        try await firebaseConfiguration.userDocumentReference
            .collection("HealthObservations_\(sampleTypeIdentifier)")
            .document(id.uuidString)
    }
}


extension MyHeartCountsStandard {
    private enum HealthDocumentChange {
        case new(sampleTypeTitle: String, count: Int, uploadMode: UploadMode)
        case deleted(sampleTypeTitle: String, count: Int)
    }
    
    private enum UploadMode: String {
        case direct
        case zlib
    }
    
    /// - returns: A closure that should be called upon completion of the uploads, and will replaces the "will upload" notifications with "did upload" notifications.
    private func showDebugWillUploadHealthDataUploadEventNotification(
        for change: HealthDocumentChange
    ) async -> @Sendable () async -> Void {
        guard enableNotifications else {
            logger.notice("NOT SCHEDULING NOTIFICATION")
            return {}
        }
        @Sendable
        func imp(stage: String) async -> String {
            let notificationCenter = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            switch change {
            case let .new(sampleTypeTitle, count, uploadMode):
                content.title = "\(stage) upload new health observations"
                content.body = "\(count) new observations for \(sampleTypeTitle). mode: \(uploadMode.rawValue)"
            case let .deleted(sampleTypeTitle, count):
                content.title = "\(stage) delete health observations"
                content.body = "\(count) deleted observations for \(sampleTypeTitle)"
            }
            let identifier = UUID().uuidString
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            try? await notificationCenter.add(request)
            return identifier
        }
        
        let notificationId = await imp(stage: "Will")
        return {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
            _ = await imp(stage: "Did")
        }
    }
}


// MARK: FHIR Observation Metadata

extension FHIRExtensionUrls {
    // SAFETY: this is in fact safe, since the FHIRPrimitive's `extension` property is empty.
    // As a result, the actual instance doesn't contain any mutable state, and since this is a let,
    // it also never can be mutated to contain any.
    /// Url of a FHIR Extension containing the user's time zone when uploading a FHIR `Observation`.
    fileprivate nonisolated(unsafe) static let sampleUploadTimeZone = "https://bdh.stanford.edu/fhir/defs/sampleUploadTimeZone".asFHIRURIPrimitive()!
    // swiftlint:disable:previous force_unwrapping
}

extension FHIRExtensionBuilderProtocol where Self == FHIRExtensionBuilder<Void> {
    static var sampleUploadTimeZone: Self {
        .init { observation in
            let ext = Extension(
                url: FHIRExtensionUrls.sampleUploadTimeZone,
                value: .string(TimeZone.current.identifier.asFHIRStringPrimitive())
            )
            observation.appendExtension(ext, replaceAllExistingWithSameUrl: true)
        }
    }
}
