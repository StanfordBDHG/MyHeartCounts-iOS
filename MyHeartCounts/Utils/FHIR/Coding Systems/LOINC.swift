//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all

import Foundation
import struct ModelsR4.FHIRPrimitive


struct LOINC: CodingProtocol {
    static var system: String { "http://loinc.org" }
    
    let rawValue: String
    let displayTitle: String?
    
    init(_ code: String, displayTitle: String? = nil) {
        self.rawValue = code
        self.displayTitle = displayTitle
    }
}


extension LOINC {
    static let phenXSixMinuteWalkTest = LOINC("62619-2")
    static let sixMinuteWalkTest = LOINC("64098-7")
    static let pedometerTrackingPanel = LOINC("55413-9")
    static let pedometerNumStepsInUnspecifiedTime = LOINC("55423-8")
    static let pedometerWalkingDistanceInUnspecifiedTime = LOINC("55430-3") // swiftlint:disable:this identifier_name
    static let exerciseDuration = LOINC("55411-3")
}


extension LOINC {
    // MARK: Exercise Activity
    static let exerciseActivity = LOINC("73985-4")
    // Answer list values
    static let exerciseActivityBicycling = LOINC("LA11837-4")
    static let exerciseActivityJogging = LOINC("LA11835-8")
    static let exerciseActivityRunning = LOINC("LA11836-6")
    static let exerciseActivitySwimming = LOINC("LA11838-2")
    static let exerciseActivityWalking = LOINC("LA11834-1")
    static let exerciseActivityWeights = LOINC("LA11839-0")
    static let exerciseActivityMixed = LOINC("LA11840-8")
}
