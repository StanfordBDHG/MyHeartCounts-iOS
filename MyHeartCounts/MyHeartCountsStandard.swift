//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseStorage
import HealthKitOnFHIR
import OSLog
@preconcurrency import PDFKit.PDFDocument
import Spezi
import SpeziAccount
import SpeziFirebaseAccount
import SpeziFirestore
import SpeziHealthKit
import SpeziQuestionnaire
import SpeziStudy
import SwiftUI


actor MyHeartCountsStandard: Standard, EnvironmentAccessible, HealthKitConstraint, AccountNotifyConstraint {
    @Application(\.logger)
    private var logger
    
    @Dependency(FirebaseConfiguration.self)
    private var configuration
    
    @Dependency(StudyManager.self)
    private var studyManager: StudyManager?
    
    init() {}
    
    
    func add(sample: HKSample) async {
        guard !FeatureFlags.disableFirebase else {
            logger.debug("Received new HealthKit sample: \(sample)")
            return
        }
        await studyManager?.handleNewHealthSample(sample)
    }
    
    func remove(sample: HKDeletedObject) async {
        guard !FeatureFlags.disableFirebase else {
            logger.debug("Received new removed healthkit sample with id \(sample.uuid)")
            return
        }
        await studyManager?.handleDeletedHealthObject(sample)
    }

//    // periphery:ignore:parameters isolation
//    func add(response: ModelsR4.QuestionnaireResponse, isolation: isolated (any Actor)? = #isolation) async {
//        let id = response.identifier?.value?.value?.string ?? UUID().uuidString
//        
//        if FeatureFlags.disableFirebase {
//            let jsonRepresentation = (try? String(data: JSONEncoder().encode(response), encoding: .utf8)) ?? ""
//            await logger.debug("Received questionnaire response: \(jsonRepresentation)")
//            return
//        }
//        
//        do {
//            try await configuration.userDocumentReference
//                .collection("HealthKit") // Add all HealthKit sources in a /QuestionnaireResponse collection.
//                .document(id) // Set the document identifier to the id of the response.
//                .setData(from: response)
//        } catch {
//            await logger.error("Could not store questionnaire response: \(error)")
//        }
//    }

    func respondToEvent(_ event: AccountNotifications.Event) async {
        switch event {
        case .deletingAccount(let accountId):
            // QUESTION we probably also need to delete some more stuff? what about the uploaded HealthKit samples?
            do {
                try await configuration.userDocumentReference.delete()
            } catch {
                logger.error("Could not delete user document: \(error)")
            }
        case .associatedAccount, .detailsChanged, .disassociatingAccount:
            break
        }
    }
}
