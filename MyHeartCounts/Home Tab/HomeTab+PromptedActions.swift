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
import SpeziLocalStorage
import SpeziSensorKit
import SpeziStudy
import SwiftUI


extension HomeTab.PromptedAction.ID {
    static let sensorKit = Self("edu.stanford.MyHeartCounts.HomeTabAction.EnableSensorKit")
}

extension HomeTab {
    @MainActor
    @propertyWrapper
    struct PromptedActions: DynamicProperty {
        // swiftlint:disable attributes
        @Environment(\.calendar) private var cal
        @Environment(StudyManager.self) private var studyManager
        @Environment(SensorKit.self) private var sensorKit
        @TriggerUpdate private var triggerUpdate
        @LocalStorageEntry(.studyActivationDate) private var studyActivationDate
        @LocalStorageEntry(.rejectedHomeTabPromptedActions) private var rejectedActionIds
        // swiftlint:enable attributes
        
        var wrappedValue: [HomeTab.PromptedAction] {
            let _ = triggerUpdate // swiftlint:disable:this redundant_discardable_let
            let actions: [HomeTab.PromptedAction]
            actions = if let studyActivationDate,
                         let daysSinceEnrollment = cal.dateComponents([.day], from: studyActivationDate, to: .now).day {
                self.actions(daysSinceEnrollment: daysSinceEnrollment)
            } else {
                []
            }
            return actions.filter { (action: HomeTab.PromptedAction) in
                !(rejectedActionIds ?? []).contains(action.id)
            }
        }
        
        var projectedValue: Self {
            self
        }
        
        @ArrayBuilder<HomeTab.PromptedAction>
        private func actions(daysSinceEnrollment: Int) -> [HomeTab.PromptedAction] {
            let shouldOfferSensorKit = SensorKit.mhcSensors.contains(where: { $0.authorizationStatus == .notDetermined })
            if daysSinceEnrollment < 21 && shouldOfferSensorKit {
                HomeTab.PromptedAction(
                    id: .sensorKit,
                    content: .init(
                        symbol: .waveformPathEcgRectangle,
                        title: "Enable SensorKit",
                        message: "ENABLE_SENSORKIT_SUBTITLE"
                    )
                ) {
                    defer {
                        Task { @MainActor in
                            $triggerUpdate()
                        }
                    }
                    let result = try await sensorKit.requestAccess(to: SensorKit.mhcSensors)
                    for sensor in result.authorized {
                        try? await sensor.startRecording()
                    }
                }
            }
        }
        
        func reject(_ actionId: PromptedAction.ID) {
            rejectedActionIds = (rejectedActionIds ?? []).union(CollectionOfOne(actionId))
        }
    }
}


extension LocalStorageKeys {
    static let rejectedHomeTabPromptedActions = LocalStorageKey<Set<HomeTab.PromptedAction.ID>>(
        "edu.stanford.MyHeartCounts.rejectedHomeTabPromptedActions",
        setting: .unencrypted(excludeFromBackup: true) // we explicitly want these to get reset when the device is restored
    )
}
