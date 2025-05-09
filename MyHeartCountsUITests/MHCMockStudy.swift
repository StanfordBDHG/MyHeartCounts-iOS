//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit
import SpeziStudyDefinition


enum MockStudyRevision: UInt {
    // swiftlint:disable identifier_name
    case v1 = 1
    // swiftlint:enable identifier_name
}


extension UUID {
//    static let mhcMockStudy = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let mhcMockStudy = UUID()
    static let healthCollectionComponent = UUID()
    static let article1 = UUID()
}


func mockStudy(revision: MockStudyRevision) -> StudyDefinition {
    StudyDefinition(
        studyRevision: revision.rawValue,
        metadata: .init(
            id: .mhcMockStudy,
            title: "MyHeart Counts",
            shortTitle: "MHC",
            icon: .systemSymbol("cube.transparent"),
            explanationText: "TODO",
            shortExplanationText: "TODO",
            studyDependency: nil,
            participationCriterion: true,
            enrollmentConditions: .none
        ),
        components: Array {
            switch revision {
            case .v1:
                StudyDefinition.Component.healthDataCollection(.init(
                    id: .healthCollectionComponent,
                    sampleTypes: [SampleType.heartRate, SampleType.bloodOxygen, SampleType.bloodPressure],
                    historicalDataCollection: .disabled
                ))
                StudyDefinition.Component.informational(.init(
                    id: .article1,
                    title: "Article1 Title",
                    headerImage: "",
                    body: "Article1 Body"
                ))
            }
        },
        componentSchedules: Array {
            switch revision {
            case .v1:
                StudyDefinition.ComponentSchedule(
                    componentId: .article1,
                    scheduleDefinition: .repeated(.weekly(weekday: .wednesday, hour: 9, minute: 0), startOffsetInDays: 0),
                    completionPolicy: .sameDayAfterStart
                )
            }
        }
    )
}
