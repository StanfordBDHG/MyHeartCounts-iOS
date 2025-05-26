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


@Observable
final class CustomHealthSampleHealthDashboardDataSource: HealthDashboardLayout.CustomDataSourceProtocol, Sendable {
    @ObservationIgnored private let customHealthSampleType: CustomHealthSample.SampleType
    @ObservationIgnored @MainActor private let modelContext: ModelContext
    @ObservationIgnored private let fetchDescriptor: FetchDescriptor<CustomHealthSample>
    
    @ObservationIgnored let sampleType: CustomQuantitySampleType
    @ObservationIgnored let timeRange: HealthKitQueryTimeRange
    
    // SAFETY: only set once, from w/in the initializer.
    nonisolated(unsafe) private var modelContextDidSaveCancellable: AnyCancellable?
    
    // SAFETY: only mutated from the MainActor
    // TODO: probably still unsafe, since a read could coincide with a write!
    nonisolated(unsafe) private var samples: [QuantitySample] = []
    
//    private var fetchResults: [CustomHealthSample] = []
//    private var token: DefaultHistoryToken?
    
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
                sample.sampleTypeRawValue == sampleTypeRawValue // TODO filter based on time range!
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
    
    
//    @MainActor private func startUpdates() {
//        let publisher = NotificationCenter.default.publisher(for: ModelContext.didSave, object: modelContext)
//        publisher.sink(receiveValue: <#T##(Notification) -> Void#>)
//        let saveNotifications = NotificationCenter.default.notifications(named: ModelContext.didSave, object: modelContext)
//        Task {
//            for try await _ in saveNotifications {
//                self.update()
//            }
//        }
//    }
    
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
    
//    private func transactionsSinceLastUpdate() throws -> [DefaultHistoryTransaction] {
//        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()
//        if let token {
//            historyDescriptor.predicate = #Predicate { transaction in
//                transaction.token > token
//            }
//        }
//        return try modelContext.fetchHistory(historyDescriptor)
//    }
    
//    private func update2() {
//        do {
//            let transactions = try transactionsSinceLastUpdate()
//            for transaction in transactions {
//                for change in transaction.changes {
//                    switch change {
//                    case .insert(let insert as DefaultHistoryInsert<CustomHealthSample>):
//                        print("INSERT", insert)
//                    case .update(let update as DefaultHistoryUpdate<CustomHealthSample>):
//                        print("UPDATE", update)
//                    case .delete(let delete as DefaultHistoryDelete<CustomHealthSample>):
//                        print("DELETE", delete)
//                    }
//                }
//            }
//        } catch {
//            // TODO
//        }
//    }
}


extension CustomHealthSampleHealthDashboardDataSource: RandomAccessCollection {
    typealias Element = QuantitySample
    typealias Index = [QuantitySample].Index
    
    var startIndex: Index {
        samples.startIndex
    }
    
    var endIndex: Index {
        samples.endIndex
    }
    
    subscript(position: Index) -> QuantitySample {
        samples[position]
    }
}

