//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import SpeziHealthKit
import SwiftData


@Observable // swiftlint:disable:next type_name
final class CustomHealthSampleHealthDashboardDataSource: HealthDashboardLayout.CustomDataSourceProtocol, Sendable {
    @ObservationIgnored private let customHealthSampleType: CustomHealthSample.SampleType
    @ObservationIgnored @MainActor private let modelContext: ModelContext
    @ObservationIgnored private let fetchDescriptor: FetchDescriptor<CustomHealthSample>
    
    @ObservationIgnored let sampleType: CustomQuantitySampleType
    @ObservationIgnored let timeRange: HealthKitQueryTimeRange
    @MainActor private(set) var samples: [QuantitySample] = []
    
    // only set once, from w/in the initializer, but we sadly can't make it immutable
    @MainActor private var modelContextDidSaveCancellable: AnyCancellable?
    
    @MainActor
    init?(modelContext: ModelContext, sampleType customHealthSampleType: CustomHealthSample.SampleType, timeRange: HealthKitQueryTimeRange) {
        guard let sampleType = CustomQuantitySampleType(customHealthSampleType) else {
            return nil
        }
        self.modelContext = modelContext
        self.customHealthSampleType = customHealthSampleType
        self.sampleType = sampleType
        self.timeRange = timeRange
        let sampleTypeRawValue = customHealthSampleType.rawValue
        self.fetchDescriptor = .init(
            predicate: #Predicate<CustomHealthSample> { sample in
                sample.sampleTypeRawValue == sampleTypeRawValue // filter based on time range?
            },
            sortBy: [SortDescriptor<CustomHealthSample>(\.startDate)]
        )
        self.modelContextDidSaveCancellable = NotificationCenter.default
            .publisher(for: ModelContext.didSave, object: modelContext)
            .sink { _ in
                self.update()
            }
        update()
    }
    
    @MainActor
    private func update() {
        let fetchedSamples = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let samples = fetchedSamples.map { sample in
            QuantitySample(
                id: sample.id,
                sampleType: .custom(sampleType),
                quantity: HKQuantity(unit: sample.unit ?? sampleType.displayUnit, doubleValue: sample.value),
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }
        self.samples = samples
    }
}
