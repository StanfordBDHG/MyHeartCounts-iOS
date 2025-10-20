//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import HealthKit
import HealthKitOnFHIR
@preconcurrency import ModelsR4
import OSLog
import SpeziAccount
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
    var enableDebugNotifications: Bool {
        let prefs = LocalPreferencesStore.standard
        return prefs[.lastSeenIsDebugModeEnabledAccountKey] && prefs[.sendHealthSampleUploadNotifications]
    }
    
    func handleNewSamples<Sample>(_ addedSamples: some Collection<Sample> & Sendable, ofType sampleType: SampleType<Sample>) async {
        do {
            try await uploadHealthObservations(addedSamples, batchSize: 100)
        } catch {
            logger.error("Error uploading HealthKit samples: \(error)")
        }
    }
    
    
    func handleDeletedObjects<Sample>(_ deletedObjects: some Collection<HKDeletedObject> & Sendable, ofType sampleType: SampleType<Sample>) async {
        let deletedObjects = Array(deletedObjects)
        logger.notice("\(#function) \(deletedObjects.count) deleted HKObjects for \(sampleType.mhcDisplayTitle)")
        let triggerDidUploadNotification = await showDebugWillUploadHealthDataUploadEventNotification(
            for: .deleted(sampleTypeTitle: sampleType.mhcDisplayTitle, count: deletedObjects.count)
        )
        guard let accountId = await account?.details?.accountId else {
            return
        }
        do {
            let collection = "HealthObservations_\(sampleType.id)"
            logger.notice("Will use bulk-delete function to delete \(deletedObjects.count) HealthKit object(s) for \(sampleType.id)")
            _ = try await Functions.functions()
                .httpsCallable("deleteHealthSamples")
                .call([
                    "userId": accountId,
                    "collection": collection,
                    "documentIds": deletedObjects.map(\.uuid.uuidString)
                ])
        } catch {
            logger.notice("Error calling bulk-delete function: \(error)")
        }
        await triggerDidUploadNotification()
    }
}


extension MyHeartCountsStandard {
    func uploadHealthObservation(_ observation: some HealthObservation & Sendable) async throws {
        try await uploadHealthObservations(CollectionOfOne(observation), batchSize: 1)
    }
    
    func uploadHealthObservations( // swiftlint:disable:this function_body_length
        _ observations: consuming some Collection<some HealthObservation & Sendable> & Sendable,
        batchSize: Int = 100
    ) async throws {
        guard !observations.isEmpty, let sampleTypeIdentifier = observations.first?.sampleTypeIdentifier else {
            return
        }
        let issuedDate = FHIRPrimitive<ModelsR4.Instant>(try .init(date: .now))
        @Sendable
        func turnIntoFHIRResource(_ observation: some HealthObservation) async throws -> ResourceProxy {
            if let observation = observation as? HKElectrocardiogram {
                let symptoms = try await observation.symptoms(from: healthKit)
                let voltages = try await observation.voltageMeasurements(from: healthKit.healthStore)
                let observation = try observation.observation(
                    symptoms: symptoms,
                    voltageMeasurements: voltages.map { (time: $0.timeOffset, value: $0.voltage) },
                    withMapping: .default,
                    issuedDate: issuedDate,
                    extensions: [.sampleUploadTimeZone]
                )
                return ResourceProxy(with: observation)
            } else {
                return try observation.resource(withMapping: .default, issuedDate: issuedDate, extensions: [.sampleUploadTimeZone])
            }
        }
        if observations.count >= 100 && observations.allSatisfy({ $0.sampleTypeIdentifier == sampleTypeIdentifier }) {
            let numObservations = observations.count
            logger.notice("Uploading \(numObservations) observations of type '\(sampleTypeIdentifier)' via zlib upload")
            let triggerDidUploadNotification = await showDebugWillUploadHealthDataUploadEventNotification(
                for: .new(sampleTypeTitle: sampleTypeIdentifier, count: numObservations, uploadMode: .zlib)
            )
            let resources = try await observations.mapAsync(turnIntoFHIRResource)
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
                        let resource = try await turnIntoFHIRResource(observation)
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
        guard enableDebugNotifications else {
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
    nonisolated(unsafe) static let sampleUploadTimeZone = "https://bdh.stanford.edu/fhir/defs/sampleUploadTimeZone".asFHIRURIPrimitive()!
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
