//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Combine
import FirebaseFirestore
import Foundation
import SpeziAccount
import SpeziHealthKit
import SwiftData


@Observable
final class FirestoreHealthDashboardDataSource: HealthDashboardLayout.CustomDataSourceProtocol, Sendable {
    @ObservationIgnored private let customHealthSampleType: CustomHealthSample.SampleType
    
    @ObservationIgnored let sampleType: CustomQuantitySampleType
    @ObservationIgnored let timeRange: HealthKitQueryTimeRange
    @MainActor private(set) var samples: [QuantitySample] = []
    
//    private let collection: CollectionReference
    
    @MainActor
    init?(account: Account?, sampleType customHealthSampleType: CustomHealthSample.SampleType, timeRange: HealthKitQueryTimeRange) {
        guard let details = account?.details else {
            return nil // TODO instead of returning nil have it just be an always-empty collection? (should be unreachable anyway...)
        }
        guard let sampleType = CustomQuantitySampleType(customHealthSampleType) else {
            return nil
        }
        self.sampleType = sampleType
        self.timeRange = timeRange
        self.customHealthSampleType = customHealthSampleType
        let collection: CollectionReference = Firestore.firestore().collection("users/\(details.accountId)/HealthObservations_\(sampleType.id)")
        collection.addSnapshotListener { querySnapshot, error in
            print(querySnapshot, error)
        }
        
//        guard let sampleType = CustomQuantitySampleType(customHealthSampleType) else {
//            return nil
//        }
//        self.modelContext = modelContext
//        self.customHealthSampleType = customHealthSampleType
//        self.sampleType = sampleType
//        self.timeRange = timeRange
//        let sampleTypeRawValue = customHealthSampleType.rawValue
//        self.fetchDescriptor = .init(
//            predicate: #Predicate<CustomHealthSample> { sample in
//                sample.sampleTypeRawValue == sampleTypeRawValue // filter based on time range?
//            },
//            sortBy: [SortDescriptor<CustomHealthSample>(\.startDate)]
//        )
//        self.modelContextDidSaveCancellable = NotificationCenter.default
//            .publisher(for: ModelContext.didSave, object: modelContext)
//            .sink { _ in
//                self.update()
//            }
//        update()
//    }
    
//    @MainActor
//    private func update() {
//        let fetchedSamples = (try? modelContext.fetch(fetchDescriptor)) ?? []
//        let samples = fetchedSamples.map { sample in
//            QuantitySample(
//                id: sample.id,
//                sampleType: .custom(sampleType),
//                quantity: HKQuantity(unit: sample.unit ?? sampleType.displayUnit, doubleValue: sample.value),
//                startDate: sample.startDate,
//                endDate: sample.endDate
//            )
//        }
//        self.samples = samples
//    }
}
