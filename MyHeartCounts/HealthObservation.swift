//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import HealthKitOnFHIR
import ModelsR4


protocol HealthObservation {
    var id: UUID { get }
    var sampleTypeIdentifier: String { get }
    
    func resource(
        withMapping mapping: HKSampleMapping,
        issuedDate: FHIRPrimitive<Instant>?,
        extensions: [any FHIRExtensionBuilderProtocol]
    ) throws -> ResourceProxy
}


extension HKSample: HealthObservation {
    var id: UUID {
        uuid
    }
    
    var sampleTypeIdentifier: String {
        sampleType.identifier
    }
}


extension TimedWalkingTestResult: HealthObservation {
    static let sampleTypeIdentifier = "MHCHealthObservationTimedWalkingTestResultIdentifier"
    
    var sampleTypeIdentifier: String {
        Self.sampleTypeIdentifier
    }
}


extension Observation {
    func addMHCAppAsSource() throws {
        let revision = HKSourceRevision(
            source: HKSource.default(),
            version: "\(Bundle.main.appVersion) (\(Bundle.main.appBuildNumber ?? -1))",
            productType: nil,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion
        )
        try self.apply(.sourceRevision, input: revision)
    }
}
