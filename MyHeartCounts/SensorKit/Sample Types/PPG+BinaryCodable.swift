//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import NIOCore
import SensorKit


extension SRPhotoplethysmogramSample: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(self.startDate.timeIntervalSince1970)
        try encoder.encode(self.nanosecondsSinceStart)
        try encoder.encode(self.temperature?.converted(to: .celsius).value)
        try encoder.encode(self.usage)
        try encoder.encode(self.opticalSamples)
        try encoder.encode(self.accelerometerSamples)
    }
}


extension SRPhotoplethysmogramSample.Usage: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(rawValue)
    }
}

extension SRPhotoplethysmogramOpticalSample: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(self.emitter)
        try encoder.encode(Array(self.activePhotodiodeIndexes))
        try encoder.encode(self.signalIdentifier)
        try encoder.encode(self.nominalWavelength.converted(to: .nanometers).value)
        try encoder.encode(self.effectiveWavelength.converted(to: .nanometers).value)
        try encoder.encode(self.samplingFrequency.converted(to: .hertz).value)
        try encoder.encode(self.nanosecondsSinceStart)
        try encoder.encode(self.conditions)
        try encoder.encode(self.noiseTerms)
        try encoder.encode(self.normalizedReflectance)
    }
}

extension SRPhotoplethysmogramOpticalSample.NoiseTerms: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(self.whiteNoise)
        try encoder.encode(self.pinkNoise)
        try encoder.encode(self.backgroundNoise)
        try encoder.encode(self.backgroundNoiseOffset)
    }
}

extension SRPhotoplethysmogramOpticalSample.Condition: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(self.rawValue)
    }
}


extension SRPhotoplethysmogramAccelerometerSample: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(self.nanosecondsSinceStart)
        try encoder.encode(self.samplingFrequency.converted(to: .hertz).value)
        try encoder.encode(self.x.converted(to: .gravity).value)
        try encoder.encode(self.y.converted(to: .gravity).value)
        try encoder.encode(self.z.converted(to: .gravity).value)
    }
}
