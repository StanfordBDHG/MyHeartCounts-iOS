//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
import Foundation
import ModelsR4
import OSLog
import Spezi
import SpeziHealthKit


extension MyHeartCountsStandard {
    // periphery:ignore:parameters isolation
    func add(isolation: isolated (any Actor)? = #isolation, _ response: ModelsR4.QuestionnaireResponse) async {
        let logger = await self.logger
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
        do {
            try await parseIfApplicable(response)
        } catch {
            logger.error("Error parsing & processing questionnaire response: \(error)")
        }
    }
    
    
    // periphery:ignore:parameters isolation
    private func parseIfApplicable(
        isolation: isolated (any Actor)? = #isolation,
        _ response: ModelsR4.QuestionnaireResponse
    ) async throws {
        switch response.questionnaire?.value?.url {
        case "https://myheartcounts.stanford.edu/fhir/survey/heartRisk":
            try await processHeartRiskSurvey(response)
        default:
            break
        }
    }
    
    
    private func processHeartRiskSurvey( // swiftlint:disable:this function_body_length
        isolation: isolated (any Actor)? = #isolation,
        _ response: QuestionnaireResponse
    ) async throws {
        let logger = await logger
        let allResponses = response.allResponses
        func answer(to questionLinkId: String) -> QuestionnaireResponseItemAnswer? {
            let responses = allResponses.filter { $0.linkId.value?.string == questionLinkId }
            guard responses.count <= 1 else {
                logger.error("Found multiple responses for question \(questionLinkId)")
                return nil
            }
            guard let answers = responses.first?.answer else {
                return nil
            }
            guard answers.count <= 1 else {
                logger.error("Found multiple answers in response for question \(questionLinkId)")
                return nil
            }
            return answers.first
        }
        
        do {
            let sys = "7cec349c-495c-4ef6-834e-cc9708625736"
            let dia = "b25ac0aa-4528-47dc-951f-97f411ec5cc2"
            let makeAndSaveSample = { (questionId: String, sampleType: SampleType<HKQuantitySample>) async throws -> HKQuantitySample? in
                switch answer(to: questionId)?.value {
                case .quantity(let quantity):
                    guard let value = quantity.value?.value?.decimal.doubleValue,
                          let unit = quantity.unit?.value?.string,
                          let unit = HKUnit.parse(unit) else {
                        return nil
                    }
                    let date = (try? response.authored?.value?.asNSDate()) ?? .now
                    let sample = HKQuantitySample(
                        type: sampleType.hkSampleType,
                        quantity: HKQuantity(unit: unit, doubleValue: value),
                        start: date,
                        end: date
                    )
                    try await self.healthKit.save(sample)
                    return sample
                default:
                    return nil
                }
            }
            // Note: intentionally not a single `if let sys = .., let dia = ...` bc that'd give us short-circuiting behaviour.
            let sysSample = try? await makeAndSaveSample(sys, .bloodPressureSystolic)
            let diaSample = try? await makeAndSaveSample(dia, .bloodPressureDiastolic)
            if let sysSample, let diaSample {
                let correlation = HKCorrelation(
                    type: SampleType.bloodPressure.hkSampleType,
                    start: min(sysSample.startDate, diaSample.startDate),
                    end: max(sysSample.endDate, diaSample.endDate),
                    objects: [sysSample, diaSample]
                )
                try await healthKit.save(correlation)
            }
        }
    }
}


private protocol QuestionnaireResponseItemContainer {
    var item: [QuestionnaireResponseItem]? { get } // swiftlint:disable:this discouraged_optional_collection
}

extension QuestionnaireResponse: QuestionnaireResponseItemContainer {}
extension QuestionnaireResponseItem: QuestionnaireResponseItemContainer {}
extension QuestionnaireResponseItemAnswer: QuestionnaireResponseItemContainer {}

extension QuestionnaireResponseItemContainer {
    var allResponses: Set<QuestionnaireResponseItem> {
        var responses = Set(self.item ?? [])
        for response in responses {
            responses.formUnion(response.allResponses)
        }
        return responses
    }
}
