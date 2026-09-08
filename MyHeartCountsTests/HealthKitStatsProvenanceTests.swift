//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
@testable import MyHeartCounts
import Testing


@Suite
struct HealthKitStatsProvenanceTests {
    @Test
    func recomputingAReadingPreservesIdentityWithoutClaimingIndependence() throws {
        let type = try #require(HKQuantityType.quantityType(forIdentifier: .bodyMass))
        let date = Date(timeIntervalSince1970: 1_788_761_600)
        let first = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gram(), doubleValue: 75_000), start: date, end: date)
        let second = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gram(), doubleValue: 75_000), start: date, end: date)
        let provenance = HealthKitStatsCalculator.provenance(for: first)
        #expect(provenance == HealthKitStatsCalculator.provenance(for: first))
        #expect(provenance.observationID == "healthkit:\(first.uuid.uuidString.lowercased())")
        #expect(provenance.observationID != HealthKitStatsCalculator.provenance(for: second).observationID)
        #expect(provenance.origins.isEmpty)
    }

    @Test(arguments: [false, true])
    func quantityWireFormatRetainsOptionalProvenance(includeProvenance: Bool) throws {
        let provenance = includeProvenance ? StatsDocument.Provenance(origins: [], observationID: "healthkit:quantity-id") : nil
        let entry = HealthKitStatsCalculator.QuantitySampleEntry(
            date: Date(timeIntervalSince1970: 1_788_761_600),
            unit: .gramUnit(with: .kilo),
            value: 75,
            provenance: provenance
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HealthKitStatsCalculator.QuantitySampleEntry.self, from: data)
        #expect(decoded.provenance == provenance)
        #expect(decoded.date == entry.date)
        #expect(decoded.value == 75)
        let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((fields["provenance"] != nil) == includeProvenance)
    }

    @Test(arguments: [false, true])
    func bloodPressureWireFormatRetainsOptionalProvenance(includeProvenance: Bool) throws {
        let provenance = includeProvenance ? StatsDocument.Provenance(origins: [], observationID: "healthkit:correlation-id") : nil
        let entry = HealthKitStatsCalculator.BloodPressureSampleEntry(
            date: Date(timeIntervalSince1970: 1_788_761_600),
            unit: .millimeterOfMercury(),
            systolic: 120,
            diastolic: 80,
            provenance: provenance
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HealthKitStatsCalculator.BloodPressureSampleEntry.self, from: data)
        #expect(decoded.provenance == provenance)
        #expect(decoded.systolic == 120)
        #expect(decoded.diastolic == 80)
        let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((fields["provenance"] != nil) == includeProvenance)
    }
}
