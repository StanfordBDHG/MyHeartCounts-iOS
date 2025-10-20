//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation
import SpeziHealthKit
import SpeziViews
import SwiftUI


struct AddSleepSessionsButton: View {
    @Environment(HealthKit.self)
    private var healthKit
    
    @Environment(\.calendar)
    private var cal
    
    @Binding var viewState: ViewState
    
    var body: some View {
        AsyncButton("Add Sleep Sessions", state: $viewState) {
            try await addSleepSamples()
        }
    }
    
    // copied from the SpeziHealthKit UITests
    private func addSleepSamples() async throws { // swiftlint:disable:this function_body_length
        struct SampleDescriptor {
            let phase: SleepSession.SleepPhase
            let duration: TimeInterval
        }
        let sampleDescriptors = [
            SampleDescriptor(phase: .asleepCore, duration: 750.0),
            SampleDescriptor(phase: .asleepDeep, duration: 300.0),
            SampleDescriptor(phase: .asleepCore, duration: 390.0),
            SampleDescriptor(phase: .asleepDeep, duration: 330.0),
            SampleDescriptor(phase: .asleepCore, duration: 30.0),
            SampleDescriptor(phase: .awake, duration: 30.0),
            SampleDescriptor(phase: .asleepCore, duration: 660.0),
            SampleDescriptor(phase: .asleepDeep, duration: 1350.0),
            SampleDescriptor(phase: .asleepCore, duration: 330.0),
            SampleDescriptor(phase: .asleepREM, duration: 630.0),
            SampleDescriptor(phase: .asleepCore, duration: 1140.0),
            SampleDescriptor(phase: .asleepDeep, duration: 1350.0),
            SampleDescriptor(phase: .asleepCore, duration: 930.0),
            SampleDescriptor(phase: .asleepDeep, duration: 390.0),
            SampleDescriptor(phase: .asleepCore, duration: 540.0),
            SampleDescriptor(phase: .asleepREM, duration: 870.0),
            SampleDescriptor(phase: .awake, duration: 60.0),
            SampleDescriptor(phase: .asleepCore, duration: 450.0),
            SampleDescriptor(phase: .asleepREM, duration: 90.0),
            SampleDescriptor(phase: .asleepCore, duration: 3180.0),
            SampleDescriptor(phase: .awake, duration: 90.0),
            SampleDescriptor(phase: .asleepCore, duration: 660.0),
            SampleDescriptor(phase: .asleepREM, duration: 2580.0),
            SampleDescriptor(phase: .asleepCore, duration: 3930.0),
            SampleDescriptor(phase: .awake, duration: 60.0),
            SampleDescriptor(phase: .asleepCore, duration: 180.0),
            SampleDescriptor(phase: .asleepREM, duration: 1350.0),
            SampleDescriptor(phase: .awake, duration: 60.0),
            SampleDescriptor(phase: .asleepCore, duration: 3690.0),
            SampleDescriptor(phase: .awake, duration: 840.0),
            SampleDescriptor(phase: .asleepCore, duration: 90.0)
        ]
        func makeSamples(from sampleDescriptors: [SampleDescriptor], startingAt startDate: Date) -> [HKCategorySample] {
            var samples: [HKCategorySample] = []
            for descriptor in sampleDescriptors {
                let start = samples.last?.endDate ?? startDate
                samples.append(HKCategorySample(
                    type: SampleType.sleepAnalysis.hkSampleType,
                    value: descriptor.phase.rawValue,
                    start: start,
                    end: start.addingTimeInterval(descriptor.duration)
                ))
            }
            return samples
        }
        let samples = makeSamples(
            from: sampleDescriptors,
            startingAt: cal.startOfPrevDay(for: cal.startOfPrevDay(for: .now))
        )
        print("Adding \(samples.count) sleep samples to health")
        try await healthKit.save(samples)
    }
}
