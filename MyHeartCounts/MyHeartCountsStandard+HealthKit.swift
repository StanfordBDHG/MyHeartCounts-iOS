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
#if DEBUG
import UserNotifications
#endif
import SpeziHealthKit


extension MyHeartCountsStandard: HealthKitConstraint {
    func handleNewSamples<Sample>(_ addedSamples: some Collection<Sample>, ofType sampleType: SampleType<Sample>) async {
//        let db: Firestore = FirebaseFirestore.Firestore.firestore()
        // IDEA instead of performing the upload right in here, maybe add it to a queue and
        // have a background task that just goes over the queue until its empty?
        // IDEA have a look at the batch/transaction APIs firebase gives us
        #if DEBUG
        await showDebugHealthKitEventNotification(for: .newSamples(sampleType, Array(addedSamples)), stage: .willUpload)
        #endif
        for sample in addedSamples {
            do {
                logger.debug("Will upload \(sample)")
                try await healthKitDocument(id: sample.uuid)
                    .setData(from: sample.resource)
            } catch {
                logger.error("Error saving HealthKit sample to Firebase: \(error)")
                // maybe queue sample for later retry?
                // (probably not needed, since firebase already seems to be doing this for us...)
            }
        }
        #if DEBUG
        await showDebugHealthKitEventNotification(for: .newSamples(sampleType, Array(addedSamples)), stage: .didUpload)
        #endif
    }
    
    func handleDeletedObjects<Sample>(_ deletedObjects: some Collection<HKDeletedObject>, ofType sampleType: SampleType<Sample>) async {
        #if DEBUG
        await showDebugHealthKitEventNotification(for: .deletedSamples(sampleType, Array(deletedObjects)), stage: .willUpload)
        #endif
        for object in deletedObjects {
            do {
                logger.debug("Will delete \(object)")
                try await healthKitDocument(id: object.uuid).delete()
            } catch {
                logger.error("Error saving HealthKit sample to Firebase: \(error)")
                // (probably not needed, since firebase already seems to be doing this for us...)
            }
        }
        #if DEBUG
        await showDebugHealthKitEventNotification(for: .deletedSamples(sampleType, Array(deletedObjects)), stage: .didUpload)
        #endif
    }
    
    
    private func healthKitDocument(id uuid: UUID) async throws -> DocumentReference {
        try await firebaseConfiguration.userDocumentReference
            .collection("HealthKitObservations") // Add all HealthKit sources in a /HealthKit collection.
            .document(uuid.uuidString) // Set the document identifier to the UUID of the document.
    }
}


#if DEBUG
extension MyHeartCountsStandard {
    enum HealthKitUploadStage: String {
        case willUpload = "will"
        case didUpload = "did"
    }
    
//    struct TrackedBackgroundHealthKitEvent {
//        
//    }
    
    enum HealthKitChange<Sample: _HKSampleWithSampleType> {
        case newSamples(SampleType<Sample>, [Sample])
        case deletedSamples(SampleType<Sample>, [HKDeletedObject])
    }
    
    private func showDebugHealthKitEventNotification<Sample>(for change: HealthKitChange<Sample>, stage: HealthKitUploadStage) async {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        switch change {
        case let .newSamples(sampleType, samples):
            content.title = "[MHC] New HealthKit Samples (\(stage.rawValue) upload)"
            content.body = "\(samples.count) new samples for \(sampleType.displayTitle)"
        case let .deletedSamples(sampleType, samples):
            content.title = "[MHC] HealthKit Samples Deleted (\(stage.rawValue) upload)"
            content.body = "\(samples.count) deleted samples for \(sampleType.displayTitle)"
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await notificationCenter.add(request)
    }
}
#endif
