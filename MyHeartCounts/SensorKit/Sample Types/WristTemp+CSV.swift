//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKitOnFHIR
import ModelsR4
import SensorKit
import SpeziFoundation
import SpeziSensorKit


extension SRWristTemperatureSession: CSVConvertibleSensorSample {
    func csvData() throws -> Data {
        let writer = try CSVWriter(columns: ["timestamp", "value", "errorEstimate", "condition"])
        for temp in self.temperatures {
            try writer.appendRow(fields: [
                temp.timestamp,
                temp.value.converted(to: .celsius).value,
                temp.errorEstimate.converted(to: .celsius).value,
                temp.condition.rawValue // TODO what to use here? the raw OptionSet? A string?
            ] as [any CSVWriter.FieldValue])
        }
        return writer.data()
    }
    
    func finalize(_ observation: Observation) throws {
        observation.id = self.id.uuidString.asFHIRStringPrimitive()
        observation.appendExtensions([
            Extension(
                url: FHIRExtensionUrls.sensorKitWristTempAlgorithmVersion,
                value: .string(self.version.asFHIRStringPrimitive())
            )
        ], replaceAllExistingWithSameUrl: true)
    }
}


extension FHIRExtensionUrls {
    nonisolated(unsafe) static let sensorKitWristTempAlgorithmVersion = Self.sensorKitDomain.appending(component: "WristTemp/algorithmVersion")
}
