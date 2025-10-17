//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziFoundation
import SpeziSensorKit
import SpeziStudy
import SwiftUI


extension HomeTab {
    @MainActor
    @propertyWrapper
    struct PromptedActions: DynamicProperty {
        // swiftlint:disable attributes
        @Environment(\.calendar) private var cal
        @Environment(StudyManager.self) private var studyManager
        @Environment(SensorKit.self) private var sensorKit
        @TriggerUpdate private var triggerUpdate
        // swiftlint:enable attributes
        
        
        var wrappedValue: [ActionCard] {
            let _ = triggerUpdate // swiftlint:disable:this redundant_discardable_let
            return if let enrollment = studyManager.studyEnrollments.first,
                      let daysSinceEnrollment = cal.dateComponents([.day], from: enrollment.enrollmentDate, to: .now).day {
                actions(daysSinceEnrollment: daysSinceEnrollment)
            } else {
                []
            }
        }
        
        @ArrayBuilder<ActionCard>
        private func actions(daysSinceEnrollment: Int) -> [ActionCard] {
            // the big issue here is that we don't just want to show some of these after the enrollment (initial) but we also went to re-prompt it when the user deletes an re-downloads rhe app!!!!!!!!1
            let shouldOfferSensorKit = SensorKit.mhcSensors.contains(where: { $0.authorizationStatus == .notDetermined })
            if daysSinceEnrollment < 21 && shouldOfferSensorKit {
                ActionCard(content: .init(
                    id: "edu.stanford.MyHeartCounts.ActionCard.SensorKit",
                    symbol: .waveformPathEcgRectangle,
                    title: "Enable SensorKit",
                    message: "ENABLE_SENSORKIT_SUBTITLE"
                )) {
                    do {
                        defer {
                            Task { @MainActor in
                                $triggerUpdate()
                            }
                        }
                        let result = try await sensorKit.requestAccess(to: SensorKit.mhcSensors)
                        for sensor in result.authorized {
                            try? await sensor.startRecording()
                        }
                    } catch {
                        print("Error enabling SensorKit: \(error)")
                    }
                }
            }
        }
    }
}
