//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
import class ModelsR4.QuestionnaireResponse
import MyHeartCountsShared
import OSLog
import Spezi
import SpeziHealthKit


extension MyHeartCountsStandard {
    // periphery:ignore:parameters isolation
    func add(isolation: isolated (any Actor)? = #isolation, _ response: ModelsR4.QuestionnaireResponse) async {
        let logger = await self.logger
        let id = response.identifier?.value?.value?.string ?? UUID().uuidString
        do {
            try await firebaseConfiguration.userDocumentReference
                .collection("questionnaireResponses") // Add all HealthKit sources in a /QuestionnaireResponse collection.
                .document(id) // Set the document identifier to the id of the response.
                .setData(from: response)
        } catch {
            logger.error("Could not store questionnaire response: \(error)")
        }
        await parseIfApplicable(response)
    }
    
    
    // periphery:ignore:parameters isolation
    private func parseIfApplicable(
        isolation: isolated (any Actor)? = #isolation,
        _ response: ModelsR4.QuestionnaireResponse
    ) async {
        typealias Rule = QuestionnaireDataExtractor.Rule
        switch response.questionnaire?.value?.url {
        case "https://myheartcounts.stanford.edu/fhir/survey/heartRisk":
            await processSurvey(response: response, rules: [
                Rule.bloodPressure(
                    systolicLinkId: "7cec349c-495c-4ef6-834e-cc9708625736",
                    diastolicLinkId: "b25ac0aa-4528-47dc-951f-97f411ec5cc2"
                ),
                Rule.quantitySample(.bloodPressureSystolic, linkId: "78edc19f-e409-49f0-8e42-a0adf5e777b0"),
                Rule.quantitySample(.bloodGlucose, linkId: "7309938e-ea24-4e31-8427-82f3a1a44f83")
            ])
        default:
            break
        }
    }
    
    
    private func processSurvey(
        isolation: isolated (any Actor)? = #isolation,
        response: QuestionnaireResponse,
        rules: [any QuestionnaireDataExtractor.AnyRule<HealthKit>]
    ) async {
        let extractor = QuestionnaireDataExtractor(response: response)
        for rule in rules {
            do {
                _ = try await rule(isolation: isolation, extractor: extractor, context: healthKit)
            } catch {
                await logger.error("Error parsing & processing questionnaire response: \(error)")
            }
        }
    }
}
