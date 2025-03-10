//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable force_unwrapping

import Foundation
import ModelsR4
import SpeziStudy


extension UUID { // QUESTION maybe use reverse-dns-strings instead of UUIDs?!
    fileprivate static let mhcStudy = UUID(uuidString: "5D464372-C9A3-4018-A789-47149D934BFC")!
    fileprivate static let mhcStudyComponentHealthDataCollection = UUID(uuidString: "BA29517B-92BB-483E-908E-7E5046C05A6C")!
    fileprivate static let mhcStudyComponentQuestionnaire1 = UUID(uuidString: "CFCB212A-F31C-403F-9FF7-F8A4340DB849")!
    fileprivate static let mhcStudyComponentInformationalBlock1 = UUID(uuidString: "E998A051-A153-4BEF-8638-F2B72CEAF5CC")!
    fileprivate static let mhcStudyComponentInformationalBlock2 = UUID(uuidString: "58BCA894-D78C-4A8A-B0CE-2395A0EB0D09")!
}


let mockMHCStudy = StudyDefinition(
    metadata: .init(
        id: .mhcStudy,
        title: "My Heart Counts",
        shortTitle: "MHC",
        icon: .systemSymbol("cube.transparent"),
        shortExplanationText: "Improve your cardiovascular health",
        explanationText: "TODO",
        studyDependency: nil,
        participationCriteria: .init(
            criterion: .ageAtLeast(18) && (.isFromRegion(.unitedStates) || .isFromRegion(.unitedKingdom))
        ),
        enrollmentConditions: .requiresInvitation(verificationEndpoint: URL(string: "https://mhc.spezi.stanford.edu/api/invite/")!)
    ),
    components: [
        .healthDataCollection(.init(
            id: .mhcStudyComponentHealthDataCollection,
            sampleTypes: .init(
                quantityTypes: [.heartRate, .stepCount, .activeEnergyBurned],
                correlationTypes: [.bloodPressure, .food],
                categoryTypes: [.sleepAnalysis]
            )
        )),
        .questionnaire(id: .mhcStudyComponentQuestionnaire1, questionnaire: mhcQuestionnaire),
        .informational(.init(
            id: .mhcStudyComponentInformationalBlock1,
            title: "Learn About Cardiovascular Diseases",
            headerImage: "abc",
            body: "TODO: have fancy content here"
        )),
        .informational(.init(
            id: .mhcStudyComponentInformationalBlock2,
            title: "The Benefits of Walking for Countering Cardiovascular Issues",
            headerImage: "def",
            body: "TODO: have some more fancy content here"
        ))
    ],
    schedule: .init(elements: [
        .init(
            componentId: .mhcStudyComponentHealthDataCollection,
            scheduleKind: .once(.studyBegin, offset: .zero),
            completionPolicy: .afterStart
        ),
        .init(
            componentId: .mhcStudyComponentQuestionnaire1,
            // ISSUE(@lukas) look into how the weekday and startOffset work with each oither!
            // eg: if we configure this as a weekly task on tuesdays, and set the startOffset to 1 and start on a monday,
            // does it start correctly on the 2nd overall day?
            // what about if we start on a monday and set the offset to 4? we;d intuetively expect it to start the following week?
            scheduleKind: .repeated(.weekly(weekday: .tuesday, hour: 09, minute: 00), startOffsetInDays: 0),
            completionPolicy: .sameDayAfterStart
        ),
        .init(
            componentId: .mhcStudyComponentInformationalBlock1,
            scheduleKind: .repeated(.weekly(weekday: .thursday, hour: 09, minute: 00), startOffsetInDays: 0),
            completionPolicy: .sameDay
        ),
        .init(
            componentId: .mhcStudyComponentInformationalBlock2,
            scheduleKind: .repeated(.weekly(weekday: .saturday, hour: 09, minute: 00), startOffsetInDays: 0),
            completionPolicy: .sameDay
        )
    ])
)


private var mhcQuestionnaire: Questionnaire {
    // swiftlint:disable:next line_length
    let json = #"{"title":"Does My Heart Count?","resourceType":"Questionnaire","language":"en-US","status":"draft","meta":{"profile":["http://spezi.health/fhir/StructureDefinition/sdf-Questionnaire"],"tag":[{"system":"urn:ietf:bcp:47","code":"en-US","display":"English"}]},"useContext":[{"code":{"system":"http://hl7.org/fhir/ValueSet/usage-context-type","code":"focus","display":"Clinical Focus"},"valueCodeableConcept":{"coding":[{"system":"urn:oid:2.16.578.1.12.4.1.1.8655","display":"Does My Heart Count?"}]}}],"contact":[{}],"subjectType":["Patient"],"item":[{"linkId":"39a1b02d-91c1-48b6-8ee4-f58b51f01eab","type":"boolean","text":"Does Your Heart Count?","required":false}]}"#
    return try! JSONDecoder().decode(Questionnaire.self, from: Data(json.utf8)) // swiftlint:disable:this force_try
}
