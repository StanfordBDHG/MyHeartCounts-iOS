//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import FHIRModelsExtensions
import Foundation
import GroveHealthKit
import GroveHealthKitFHIR
import ModelsR4


struct QuestionnaireDataExtractor {
    let response: QuestionnaireResponse

    init(response: QuestionnaireResponse) {
        self.response = response
    }

    func answer(to questionLinkId: String) throws -> QuestionnaireResponseItemAnswer? {
        let responses = response.allItems.filter { $0.linkId.value?.string == questionLinkId }
        guard responses.count <= 1 else {
            throw QuestionnaireDataExtractionError.ambiguousAnswer(linkID: questionLinkId)
        }
        guard let answers = responses.first?.answer, !answers.isEmpty else {
            return nil
        }
        guard answers.count == 1 else {
            throw QuestionnaireDataExtractionError.ambiguousAnswer(linkID: questionLinkId)
        }
        return answers.first
    }
}


enum QuestionnaireDataExtractionError: Error, Equatable {
    case ambiguousAnswer(linkID: String)
    case ambiguousBloodPressure(systolicLinkID: String, diastolicLinkID: String)
    case uncorrelatedBloodPressure(systolicLinkID: String, diastolicLinkID: String)
    case missingAuthoredDate
    case incompleteQuantity(linkID: String)
    case unsupportedQuantitySystem(linkID: String, system: String?)
    case unsupportedQuantityCode(linkID: String, code: String)
    case incompatibleQuantityUnit(linkID: String, code: String)
}


extension QuestionnaireDataExtractor {
    protocol AnyRule<Context>: Sendable {
        associatedtype Context: Sendable
        associatedtype Output: Sendable
        func callAsFunction(
            isolation: isolated (any Actor)?,
            extractor: QuestionnaireDataExtractor,
            context: Context
        ) async throws -> Output
    }
    
    
    struct Rule<Context: Sendable, Output: Sendable>: AnyRule {
        typealias Imp = @Sendable (
            _ isolation: isolated (any Actor)?,
            _ extractor: QuestionnaireDataExtractor,
            _ context: Context
        ) async throws -> Output
        
        private let imp: Imp
        
        init(_ imp: @escaping Imp) {
            self.imp = imp
        }
        
        @discardableResult
        func callAsFunction(
            isolation: isolated (any Actor)? = #isolation,
            extractor: QuestionnaireDataExtractor,
            context: Context
        ) async throws -> Output {
            try await imp(isolation, extractor, context)
        }
    }
}


extension QuestionnaireDataExtractor.Rule {
    /// A rule that extracts a quanity answer, turns it into an `HKQuantitySample`, and saves that to HealthKit.
    static func quantitySample(
        _ sampleType: SampleType<HKQuantitySample>,
        linkId: String
    ) -> Self where Context == HealthKit, Output == HKQuantitySample? {
        Self { _, extractor, healthKit in
            guard let sample = try extractor.quantitySample(sampleType, linkID: linkId) else {
                return nil
            }
            try await healthKit.save(sample)
            return sample
        }
    }
    
    /// A rule that extracts quanity answers for systolic and diastolic blood pressure, turns these into an `HKCorrelation`, and saves that to HealthKit.
    static func bloodPressure(
        systolicLinkId: String,
        diastolicLinkId: String
    ) -> Self where Context == HealthKit, Output == Void {
        Self { _, extractor, healthKit in
            guard let correlation = try extractor.bloodPressureCorrelation(
                systolicLinkID: systolicLinkId,
                diastolicLinkID: diastolicLinkId
            ) else {
                return
            }
            // Save only the correlation. Saving the components individually first creates three
            // HealthKit records for one blood-pressure answer and breaks their shared identity.
            try await healthKit.save(correlation)
        }
    }
}


extension QuestionnaireDataExtractor {
    func quantitySample(
        _ sampleType: SampleType<HKQuantitySample>,
        linkID: String
    ) throws -> HKQuantitySample? {
        guard let answer = try answer(to: linkID) else {
            return nil
        }
        return try quantitySample(sampleType, answer: answer, linkID: linkID)
    }

    private func quantitySample(
        _ sampleType: SampleType<HKQuantitySample>,
        answer: QuestionnaireResponseItemAnswer,
        linkID: String
    ) throws -> HKQuantitySample {
        guard case .quantity(let quantity) = answer.value,
              let value = quantity.value?.value?.decimal.doubleValue else {
            throw QuestionnaireDataExtractionError.incompleteQuantity(linkID: linkID)
        }
        guard let code = quantity.code?.value?.string else {
            throw QuestionnaireDataExtractionError.incompleteQuantity(linkID: linkID)
        }
        let system = quantity.system?.value?.url.absoluteString
        guard system == "http://unitsofmeasure.org" else {
            throw QuestionnaireDataExtractionError.unsupportedQuantitySystem(
                linkID: linkID,
                system: system
            )
        }
        guard let unit = HealthKitCatalog.unit(forUCUMCode: code) else {
            throw QuestionnaireDataExtractionError.unsupportedQuantityCode(linkID: linkID, code: code)
        }
        let healthKitQuantity = HKQuantity(unit: unit, doubleValue: value)
        guard healthKitQuantity.is(compatibleWith: sampleType.canonicalUnit) else {
            throw QuestionnaireDataExtractionError.incompatibleQuantityUnit(linkID: linkID, code: code)
        }
        guard let authoredDateTime = response.authored?.value else {
            throw QuestionnaireDataExtractionError.missingAuthoredDate
        }
        let authored = try authoredDateTime.asNSDate() as Date
        return HKQuantitySample(
            type: sampleType.hkSampleType,
            quantity: healthKitQuantity,
            start: authored,
            end: authored
        )
    }

    func bloodPressureCorrelation(
        systolicLinkID: String,
        diastolicLinkID: String
    ) throws -> HKCorrelation? {
        guard let items = try bloodPressureItems(
            systolicLinkID: systolicLinkID,
            diastolicLinkID: diastolicLinkID
        ) else {
            return nil
        }
        guard let systolicAnswer = try answer(in: items.systolic, linkID: systolicLinkID),
              let diastolicAnswer = try answer(in: items.diastolic, linkID: diastolicLinkID) else {
            return nil
        }
        let systolic = try quantitySample(
            SampleType<HKQuantitySample>.bloodPressureSystolic,
            answer: systolicAnswer,
            linkID: systolicLinkID
        )
        let diastolic = try quantitySample(
            SampleType<HKQuantitySample>.bloodPressureDiastolic,
            answer: diastolicAnswer,
            linkID: diastolicLinkID
        )
        return HKCorrelation(
            type: SampleType.bloodPressure.hkSampleType,
            start: min(systolic.startDate, diastolic.startDate),
            end: max(systolic.endDate, diastolic.endDate),
            objects: [systolic, diastolic]
        )
    }

    private func bloodPressureItems(
        systolicLinkID: String,
        diastolicLinkID: String
    ) throws -> (systolic: QuestionnaireResponseItem, diastolic: QuestionnaireResponseItem)? {
        let scopes = response.itemScopes
        let systolicItems = response.allItems.filter { $0.linkId.value?.string == systolicLinkID }
        let diastolicItems = response.allItems.filter { $0.linkId.value?.string == diastolicLinkID }
        let pairedScopes = scopes.filter { scope in
            scope.contains { $0.linkId.value?.string == systolicLinkID }
                && scope.contains { $0.linkId.value?.string == diastolicLinkID }
        }
        guard !pairedScopes.isEmpty else {
            if !systolicItems.isEmpty, !diastolicItems.isEmpty {
                throw QuestionnaireDataExtractionError.uncorrelatedBloodPressure(
                    systolicLinkID: systolicLinkID,
                    diastolicLinkID: diastolicLinkID
                )
            }
            return nil
        }
        guard pairedScopes.count == 1 else {
            throw QuestionnaireDataExtractionError.ambiguousBloodPressure(
                systolicLinkID: systolicLinkID,
                diastolicLinkID: diastolicLinkID
            )
        }
        let scope = pairedScopes[0]
        let matchingSystolic = scope.filter { $0.linkId.value?.string == systolicLinkID }
        let matchingDiastolic = scope.filter { $0.linkId.value?.string == diastolicLinkID }
        guard matchingSystolic.count == 1, matchingDiastolic.count == 1 else {
            throw QuestionnaireDataExtractionError.ambiguousBloodPressure(
                systolicLinkID: systolicLinkID,
                diastolicLinkID: diastolicLinkID
            )
        }
        return (matchingSystolic[0], matchingDiastolic[0])
    }

    private func answer(
        in item: QuestionnaireResponseItem,
        linkID: String
    ) throws -> QuestionnaireResponseItemAnswer? {
        guard let answers = item.answer, !answers.isEmpty else {
            return nil
        }
        guard answers.count == 1 else {
            throw QuestionnaireDataExtractionError.ambiguousAnswer(linkID: linkID)
        }
        return answers[0]
    }
}


private protocol QuestionnaireResponseItemContainer {
    var item: [QuestionnaireResponseItem]? { get } // swiftlint:disable:this discouraged_optional_collection
}

extension QuestionnaireResponse: QuestionnaireResponseItemContainer {}
extension QuestionnaireResponseItem: QuestionnaireResponseItemContainer {}
extension QuestionnaireResponseItemAnswer: QuestionnaireResponseItemContainer {}

extension QuestionnaireResponseItemContainer {
    var allItems: [QuestionnaireResponseItem] {
        itemScopes.flatMap { $0 }
    }

    var itemScopes: [[QuestionnaireResponseItem]] {
        guard let item, !item.isEmpty else {
            return []
        }
        return [item] + item.flatMap { responseItem in
            responseItem.itemScopes + (responseItem.answer ?? []).flatMap(\.itemScopes)
        }
    }
}
