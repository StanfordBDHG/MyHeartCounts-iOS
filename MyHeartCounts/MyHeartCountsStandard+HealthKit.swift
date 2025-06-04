//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import Foundation
import HealthKit
import HealthKitOnFHIR
import enum ModelsR4.ResourceProxy
import struct ModelsR4.FHIRPrimitive
import struct ModelsR4.Instant
import SpeziHealthKit
import UserNotifications


extension LocalPreferenceKey {
    static var sendHealthSampleUploadNotifications: LocalPreferenceKey<Bool> {
        .make("sendHealthSampleUploadNotifications", default: false)
    }
}


extension MyHeartCountsStandard: HealthKitConstraint {
    private var enableNotifications: Bool {
        enableDebugMode && LocalPreferencesStore.standard[.sendHealthSampleUploadNotifications]
    }
    
    func handleNewSamples<Sample>(_ addedSamples: some Collection<Sample>, ofType sampleType: SampleType<Sample>) async {
        // IDEA instead of performing the upload right in here, maybe add it to a queue and
        // have a background task that just goes over the queue until its empty?
        // IDEA have a look at the batch/transaction APIs firebase gives us
        var willUploadNotificationId: String?
        if enableNotifications {
            willUploadNotificationId = await showDebugHealthKitEventNotification(
                for: .new(sampleTypeTitle: sampleType.displayTitle, count: addedSamples.count),
                stage: .willUpload
            )
        }
        do {
            try await uploadHealthObservations(addedSamples, batchSize: 100)
        } catch {
            logger.error("Error uploading HealthKit samples: \(error)")
        }
        if enableNotifications {
            if let willUploadNotificationId {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [willUploadNotificationId])
            }
            await showDebugHealthKitEventNotification(
                for: .new(sampleTypeTitle: sampleType.displayTitle, count: addedSamples.count),
                stage: .didUpload
            )
        }
    }
    
    
    func handleDeletedObjects<Sample>(_ deletedObjects: some Collection<HKDeletedObject>, ofType sampleType: SampleType<Sample>) async {
        var willUploadNotificationId: String?
        if enableNotifications {
            willUploadNotificationId = await showDebugHealthKitEventNotification(
                for: .deleted(sampleTypeTitle: sampleType.displayTitle, count: deletedObjects.count),
                stage: .willUpload
            )
        }
        for object in deletedObjects {
            do {
                logger.debug("Will delete \(object)")
                try await healthObservationDocument(forSampleType: sampleType.hkSampleType.identifier, id: object.uuid).delete()
            } catch {
                logger.error("Error saving HealthKit sample to Firebase: \(error)")
                // (probably not needed, since firebase already seems to be doing this for us...)
            }
        }
        if enableNotifications {
            if let willUploadNotificationId {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [willUploadNotificationId])
            }
            await showDebugHealthKitEventNotification(
                for: .deleted(sampleTypeTitle: sampleType.displayTitle, count: deletedObjects.count),
                stage: .didUpload
            )
        }
    }
}


extension MyHeartCountsStandard {
    func uploadHealthObservation(_ observation: some HealthObservation & Sendable) async throws {
        try await uploadHealthObservations(CollectionOfOne(observation), batchSize: 1)
    }
    
    func uploadHealthObservations(_ observations: some Collection<some HealthObservation & Sendable>, batchSize: Int = 100) async throws {
        let issuedDate = FHIRPrimitive<ModelsR4.Instant>(try .init(date: .now))
        for chunk in observations.chunks(ofCount: batchSize) {
            let batch = Firestore.firestore().batch()
            for observation in chunk {
                do {
                    let document = try await healthObservationDocument(for: observation)
                    try batch.setData(
                        from: observation.resource(withMapping: .default, issuedDate: issuedDate),
                        forDocument: document
                    )
                } catch {
                    logger.error("Error saving health observation to Firebase: \(error); input: \(String(describing: observation))")
                }
            }
            try await batch.commit()
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
    private enum HealthDocumentUploadStage: String {
        case willUpload = "will"
        case didUpload = "did"
    }
    
    private enum HealthDocumentChange {
        case new(sampleTypeTitle: String, count: Int)
        case deleted(sampleTypeTitle: String, count: Int)
    }
    
    @discardableResult
    private func showDebugHealthKitEventNotification(for change: HealthDocumentChange, stage: HealthDocumentUploadStage) async -> String {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        switch change {
        case let .new(sampleTypeTitle, count):
            content.title = "[MHC] \(stage.rawValue) upload new health observations"
            content.body = "\(count) new observations for \(sampleTypeTitle)"
        case let .deleted(sampleTypeTitle, count):
            content.title = "[MHC] \(stage.rawValue) delete health observations"
            content.body = "\(count) deleted observations for \(sampleTypeTitle)"
        }
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await notificationCenter.add(request)
        return identifier
    }
}
