//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import Foundation
import SwiftData
import SpeziStudy
// NOTE: we need to import it like this, since if we were to import the whole of ModelsR4, we'd have a name collision
// between the `Observation` type defines in ModelsR4, and Apple's `Observation` framework, and the @Model macro expansion would fail to compile...
import class ModelsR4.QuestionnaireResponse



@Model
final class StudyParticipationContext {
    @Attribute(.unique)
    private(set) var id = UUID()
    
    /// The date when the participant enrolled into the study.
    ///
    /// This date is used as the reference for any relative date operations (e.g.: scheduling tasks relative to the start of someome's participation in a study).
    private(set) var enrollmentDate = Date()
    
    private(set) var study: StudyDefinition
    
//    private(set) var study: StudyDefinition {
//        @storageRestrictions(initializes: studyData)
//        init {
//            studyData = try! JSONEncoder().encode(newValue)
//        }
//        set {
//            studyData = try! JSONEncoder().encode(newValue)
//        }
//        get {
//            try! JSONDecoder().decode(StudyDefinition.self, from: studyData)
//        }
//    }
    
    @Relationship(deleteRule: .cascade, inverse: \SPCQuestionnaireEntry.SPC)
    var answeredQuestionnaires: [SPCQuestionnaireEntry] = []
    
    init(study: StudyDefinition) {
        self.study = study
    }
}



//@Model
//final class SPCEntryQuestionnaireResponse {
//    @Attribute(.unique)
//    private(set) var id = UUID()
//
//    private(set) var SPC: StudyParticipationContext?
//
//    var questionnaireResponse: QuestionnaireResponse
//
//    init(SPC: StudyParticipationContext, questionnaireResponse: QuestionnaireResponse) {
//        self.SPC = SPC
//        self.questionnaireResponse = questionnaireResponse
//    }
//}



final class JSONEncodingValueTransformer<T: Codable & AnyObject>: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        T.self
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? T else {
            fatalError() // ???
            return nil
        }
        return try! JSONEncoder().encode(value) as NSData // swiftlint:disable:this force_try
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            fatalError() // ???
            return nil
        }
        return try! JSONDecoder().decode(T.self, from: data) // swiftlint:disable:this force_try
    }
}


@Model
class SPCQuestionnaireEntry {
    @Attribute(.unique)
    private(set) var id = UUID()
    
    private(set) var SPC: StudyParticipationContext
    
    @Attribute(.transformable(by: JSONEncodingValueTransformer<QuestionnaireResponse>.self))
    var response: QuestionnaireResponse
    
//    var value: QuestionnaireResponse {
//        get {
//            try! JSONDecoder().decode(T.self, from: data)
//        }
//        set {
//            data = try! JSONEncoder().encode(newValue)
//        }
//    }
    
    init(SPC: StudyParticipationContext, response: QuestionnaireResponse) {
        self.SPC = SPC
//        self.data = try! JSONEncoder().encode(value)
        self.response = response
    }
}
