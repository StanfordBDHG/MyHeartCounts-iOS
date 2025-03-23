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
import SpeziHealthKit


extension MyHeartCountsStandard: HealthKitConstraint {
    func handleNewSamples<Sample>(_ addedSamples: some Collection<Sample>, ofType sampleType: SampleType<Sample>) async {
//        let db: Firestore = FirebaseFirestore.Firestore.firestore()
        // IDEA instead of performing the upload right in here, maybe add it to a queue and
        // have a background task that just goes over the queue until its empty?
        // IDEA have a look at the batch/transaction APIs firebase gives us
        for sample in addedSamples {
            do {
                try await healthKitDocument(id: sample.uuid)
                    .setData(from: sample.resource)
            } catch {
                logger.error("Error saving HealthKit sample to Firebase: \(error)")
                // maybe queue sample for later retry?
                // (probably not needed, since firebase already seems to be doing this for us...)
            }
        }
    }
    
    func handleDeletedObjects<Sample>(_ deletedObjects: some Collection<HKDeletedObject>, ofType sampleType: SampleType<Sample>) async {
        for object in deletedObjects {
            do {
                try await healthKitDocument(id: object.uuid).delete()
            } catch {
                logger.error("Error saving HealthKit sample to Firebase: \(error)")
                // (probably not needed, since firebase already seems to be doing this for us...)
            }
        }
    }
    
    
    private func healthKitDocument(id uuid: UUID) async throws -> DocumentReference {
        try await firebaseConfiguration.userDocumentReference
            .collection("HealthKitObservations") // Add all HealthKit sources in a /HealthKit collection.
            .document(uuid.uuidString) // Set the document identifier to the UUID of the document.
    }
}
