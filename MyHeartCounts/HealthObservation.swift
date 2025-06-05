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
import MyHeartCountsShared


protocol HealthObservation {
    var id: UUID { get }
    var sampleTypeIdentifier: String { get }
    
    func resource(withMapping: HKSampleMapping, issuedDate: FHIRPrimitive<Instant>?) throws -> ResourceProxy
}


extension HKSample: HealthObservation {
    var sampleTypeIdentifier: String {
        sampleType.identifier
    }
}


extension TimedWalkingTestResult: HealthObservation {
    var sampleTypeIdentifier: String {
        "MHCHealthObservationTimedWalkingTestResultIdentifier"
    }
}
