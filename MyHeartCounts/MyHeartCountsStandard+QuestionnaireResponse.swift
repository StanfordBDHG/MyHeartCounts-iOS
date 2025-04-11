//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
import Spezi
import class ModelsR4.QuestionnaireResponse
import Foundation


extension MyHeartCountsStandard {
    // periphery:ignore:parameters isolation
    func add(response: ModelsR4.QuestionnaireResponse, isolation: isolated (any Actor)? = #isolation) async {
        logger.notice("Will upload questionnaire response!!!")
        
        let id = response.identifier?.value?.value?.string ?? UUID().uuidString
        
        if FeatureFlags.disableFirebase {
            let jsonRepresentation = (try? String(data: JSONEncoder().encode(response), encoding: .utf8)) ?? ""
            logger.debug("Received questionnaire response: \(jsonRepresentation)")
            return
        }
        
        do {
            try await firebaseConfiguration.userDocumentReference
                .collection("questionnaireResponses") // Add all HealthKit sources in a /QuestionnaireResponse collection.
                .document(id) // Set the document identifier to the id of the response.
                .setData(from: response)
        } catch {
            logger.error("Could not store questionnaire response: \(error)")
        }
    }
}
