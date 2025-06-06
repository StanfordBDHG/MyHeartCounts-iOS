//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Combine
import FirebaseFirestore
import SwiftData
import SpeziAccount
import SpeziHealthKit
import enum ModelsR4.ResourceProxy
import Observation


@Observable
final class FirestoreHealthDashboardDataSource: HealthDashboardLayout.CustomDataSourceProtocol, Sendable {
    @ObservationIgnored private let customHealthSampleType: CustomHealthSample.SampleType
    
    @ObservationIgnored let sampleType: CustomQuantitySampleType
    @ObservationIgnored let timeRange: HealthKitQueryTimeRange
    @MainActor private(set) var samples: [QuantitySample] = []
    
    @MainActor
    init?(account: SpeziAccount.Account?, sampleType customHealthSampleType: CustomHealthSample.SampleType, timeRange: HealthKitQueryTimeRange) {
        print(Self.self, #function)
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
        collection.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self else {
                return
            }
            if let querySnapshot {
                let samples: [QuantitySample] = querySnapshot.documents.compactMap { document in
                    if let proxy = try? document.data(as: ResourceProxy.self),
                       let sample = QuantitySample(proxy) {
                        return sample
                    } else {
                        return nil
                    }
                }
                _Concurrency.Task { @MainActor in
                    self.samples = samples
                }
            }
        }
    }
    
    deinit {
        print(Self.self, #function)
    }
}
