//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import FirebaseFirestore
import HealthKitOnFHIR
import struct ModelsR4.DateTime
import struct ModelsR4.FHIRPrimitive
import struct ModelsR4.FHIRURI
import class ModelsR4.Period
import enum ModelsR4.ResourceProxy
import SpeziAccount
import SpeziFoundation
import SpeziHealthKit
import Foundation
import SwiftUI


/// An alternative to Firebase's `FirestoreQuery`, with some changes based on our specific needs in MyHeart Counts:
///
/// Differences to the `@FirestoreQuery` API:
/// - ability to not only transform the documents into a custom `Decodable` type, but then (optionally) also implicitly project into a different type from that
///     (required bc we don't want to have to operate directly on FHIR Observations and eg want to turn them into our ``QuantitySample``s instead)
@MainActor
@propertyWrapper
struct MHCFirestoreQuery<Element: Sendable>: DynamicProperty {
    typealias DecodeFn = @Sendable (QueryDocumentSnapshot) -> Element?
    
    @Environment(Account.self)
    private var account: Account?
    
    @State private var impl = Impl<Element>()
    private let input: QueryInput
    
    var wrappedValue: [Element] {
        impl.elements
    }
    
    init(
        _: Element.Type = Element.self,
        collection: String,
        filter: Filter,
        sortBy sortDescriptors: [SortDescriptor] = [],
        limit: Int? = nil,
        decode: @escaping DecodeFn
    ) {
        input = .init(
            collection: collection,
            filter: filter,
            sortDescriptors: sortDescriptors,
            limit: limit,
            decode: decode
        )
    }
    
    nonisolated func update() {
        var input = self.input
        runOrScheduleOnMainActor {
            guard let accountId = account?.details?.accountId else {
                return
            }
            input.collection = "users/\(accountId)/" + input.collection
            impl.setup(input: input)
        }
    }
}


extension MHCFirestoreQuery {
    struct SortDescriptor: Sendable {
        let fieldName: String
        let order: SortOrder
    }
    
    fileprivate struct QueryInput: Sendable {
        var collection: String
        var filter: Filter?
        var sortDescriptors: [SortDescriptor]
        var limit: Int?
        var decode: DecodeFn
    }
}


@Observable
@MainActor
private final class Impl<Element: Sendable>: Sendable {
    typealias QueryInput = MHCFirestoreQuery<Element>.QueryInput
    
    @ObservationIgnored private var listener: (any ListenerRegistration)?
    private(set) var elements: [Element] = []
    
    init() {}
    
    func setup(input: QueryInput) {
        guard listener == nil else {
            return
        }
        listener?.remove()
        var query: Query = Firestore.firestore().collection(input.collection)
        if let filter = input.filter {
            query = query.whereFilter(filter)
        }
        for sortDescriptor in input.sortDescriptors {
            query = query.order(by: sortDescriptor.fieldName, descending: sortDescriptor.order == .reverse)
        }
        if let limit = input.limit, limit > 0 {
            query = query.limit(to: limit)
        }
        listener = query.addSnapshotListener { @Sendable [weak self] snapshot, error in
            guard let self else {
                return
            }
            if let snapshot {
                Task {
                    await self.handleSnapshot(snapshot, input: input)
                }
            } else if let error {
                logger.error("encountered error in firebase snapshot listener: \(error)")
            }
        }
    }
    
    nonisolated private func handleSnapshot(_ snapshot: QuerySnapshot, input: QueryInput) async {
        var elements = await self.elements
        elements.removeAll(keepingCapacity: true)
        for document in snapshot.documents {
            if let element = input.decode(document) {
                elements.append(element)
            }
        }
        await MainActor.run {
            self.elements = elements
        }
    }
}


// MARK: Extensions

extension MHCFirestoreQuery where Element == QuantitySample {
    init(sampleType: CustomQuantitySampleType, timeRange: HealthKitQueryTimeRange, limit: Int? = nil) {
        input = .init(
            collection: "HealthObservations_\(sampleType.id)",
            filter: nil,
            sortDescriptors: [],
            limit: nil
        ) { document -> QuantitySample? in
            if timeRange != .ever {
                let data = document.data()
                if false {
                    return nil
//                    guard let extensions = data["extension"] as? [[String: Any]] else {
//                        return nil
//                    }
//                    let getDate = { (url: FHIRPrimitive<FHIRURI>) -> Date? in
//                        extensions.firstNonNil { extensionDict -> Date? in
//                            guard extensionDict["url"] as? String == url.value?.url.absoluteString,
//                                  let value = extensionDict["valueDecimal"] as? Double else {
//                                return nil
//                            }
//                            return Date(timeIntervalSince1970: value)
//                        }
//                    }
//                    guard let startDate = getDate(FHIRExtensionUrls.absoluteTimeRangeStart),
//                          let endDate = getDate(FHIRExtensionUrls.absoluteTimeRangeEnd) else {
//                        // we want to filter based on time range, but we can't extract a time range to filter against from the document
//                        return nil
//                    }
//                    guard (startDate..<endDate).overlaps(timeRange.range) else {
//                        return nil
//                    }
                } else {
                    if let dateString = data["effectiveDateTime"] as? String {
                        guard let date = try? DateTime(dateString).asNSDate() else {
                            return nil
                        }
                        guard timeRange.range.contains(date) else {
                            return nil
                        }
                    } else if let periodDict = data["effectivePeriod"] as? [String: String] {
                        guard let start = periodDict["start"].flatMap({ try? DateTime($0).asNSDate() }),
                              let end = periodDict["end"].flatMap({ try? DateTime($0).asNSDate() }) else {
                            return nil
                        }
                        guard (start..<end).overlaps(timeRange.range) else {
                            return nil
                        }
                    } else {
                        // we want to filter based on time range, but we can't extract a time range to filter against from the document
                        return nil
                    }
                }
            }
            guard let proxy = try? document.data(as: ResourceProxy.self) else {
                return nil
            }
            return QuantitySample(proxy, sampleTypeHint: .custom(sampleType))
        }
    }
}
