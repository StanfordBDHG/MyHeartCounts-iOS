//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

#if os(iOS)
public import SensorKit


extension PPGSample {
    /// Creates an instance from a SensorKit `SRPhotoplethysmogramSample` sample.
    @inlinable
    public init(_ sample: SRPhotoplethysmogramSample) {
        self.init(
            startDate: sample.startDate,
            nanosecondsSinceStart: sample.nanosecondsSinceStart,
            usage: sample.usage.map { .init($0) },
            opticalSamples: sample.opticalSamples.map { .init($0) },
            accelerometerSamples: sample.accelerometerSamples.map { .init($0) },
            temperature: sample.temperature?.value
        )
    }
}


extension PPGSample.Usage {
    /// Creates an instance from a SensorKit `SRPhotoplethysmogramSample.Usage` value.
    @inlinable
    public init(_ other: SRPhotoplethysmogramSample.Usage) {
        self.init(rawValue: other.rawValue)
    }
}


extension PPGSample.OpticalSample {
    /// Creates an instance from a SensorKit `SRPhotoplethysmogramOpticalSample`.
    @inlinable
    public init(_ other: SRPhotoplethysmogramOpticalSample) {
        self.init(
            emitter: other.emitter,
            activePhotodiodeIndexes: Set(other.activePhotodiodeIndexes),
            signalIdentifier: other.signalIdentifier,
            nominalWavelength: other.nominalWavelength.converted(to: .nanometers).value,
            effectiveWavelength: other.effectiveWavelength.converted(to: .nanometers).value,
            samplingFrequency: other.samplingFrequency.converted(to: .hertz).value,
            nanosecondsSinceStart: other.nanosecondsSinceStart,
            conditions: other.conditions.map { .init(rawValue: $0.rawValue) },
            noiseTerms: other.noiseTerms.map { .init($0) },
            normalizedReflectance: other.normalizedReflectance,
        )
    }
}


extension PPGSample.OpticalSample.NoiseTerms {
    /// Creates an instance from a SensorKit `SRPhotoplethysmogramOpticalSample.NoiseTerms` value.
    @inlinable
    public init(_ other: SRPhotoplethysmogramOpticalSample.NoiseTerms) {
        self.init(
            whiteNoise: other.whiteNoise,
            pinkNoise: other.pinkNoise,
            backgroundNoise: other.backgroundNoise,
            backgroundNoiseOffset: other.backgroundNoiseOffset
        )
    }
}


extension PPGSample.AccelerometerSample {
    /// Creates an instance from a SensorKit `SRPhotoplethysmogramAccelerometerSample`.
    @inlinable
    public init(_ other: SRPhotoplethysmogramAccelerometerSample) {
        self.init(
            nanosecondsSinceStart: other.nanosecondsSinceStart,
            samplingFrequency: other.samplingFrequency.converted(to: .hertz).value,
            x: other.x.converted(to: .gravity).value,
            y: other.y.converted(to: .gravity).value,
            z: other.z.converted(to: .gravity).value
        )
    }
}
#endif
