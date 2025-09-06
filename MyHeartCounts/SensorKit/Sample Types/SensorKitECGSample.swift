//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import Foundation
import HealthKitOnFHIR
import ModelsR4
import SpeziFoundation
import SpeziSensorKit


struct SensorKitECGSession: Hashable, Sendable {
    struct Batch: Hashable, Sendable {
        struct VoltageSample: Hashable, Sendable {
            let flags: SRElectrocardiogramData.Flags
            /// Value of the ECG AC data in microvolts
            let voltage: Measurement<UnitElectricPotentialDifference>
            
            init(_ data: SRElectrocardiogramData) {
                flags = data.flags
                voltage = data.value
            }
        }
        
        /// The batch's offset from the start of the ECG, in seconds.
        let offset: TimeInterval
        /// The batch's voltage samples.
        let samples: [VoltageSample]
    }
    
    static var sensor: Sensor<SRElectrocardiogramSample> {
        Sensor.ecg
    }
    
    let id: UUID
    
    /// Start date of the overall ECG.
    let startDate: Date
    
    /// The total duration of the ECG.
    let duration: TimeInterval
    
    /// Frequency in hertz at which the ECG data was recorded.
    let frequency: Measurement<UnitFrequency>
    
    /// The lead that was used when recording the ECG data.
    let lead: SRElectrocardiogramSample.Lead
    
    /// The individual batches of data.
    let batches: [Batch]
    
    fileprivate init(startDate: Date, frequency: Measurement<UnitFrequency>, lead: SRElectrocardiogramSample.Lead, batches: [Batch]) {
        assert(batches.isSorted { $0.offset < $1.offset })
        self.id = UUID()
        self.startDate = startDate
        self.duration = batches.last?.offset ?? 0
        self.frequency = frequency
        self.lead = lead
        self.batches = batches
    }
}


// MARK: SensorKit ECG Session Processing

extension SRElectrocardiogramSample: HasCustomSamplesProcessor {
    struct Processor: SensorKitSamplesProcessor {
        typealias Input = SRElectrocardiogramSample
        typealias Output = [SensorKitECGSession]
        
        static func process(
            _ samples: some Sequence<(timestamp: Date, sample: SRElectrocardiogramSample)>
        ) throws -> [SensorKitECGSession] {
            let samplesBySession = Dictionary(grouping: samples.lazy.map(\.sample), by: \.session)
            guard !samplesBySession.isEmpty || samplesBySession.contains(where: { !$0.value.isEmpty }) else {
                return []
            }
            // NOTE: it seems that an `SRElectrocardiogramSession` object does not, as one might intuitively expect,
            // correlate to a single session for which the ECG sensor was active.
            // Instead, there will be multiple `SRElectrocardiogramSession` objects for a single logical session
            // (they will all have the same `identifier`), each representing a different state of the session.
            let sessionsByIdentifier = Dictionary(grouping: samplesBySession.keys, by: \.identifier)
            return sessionsByIdentifier.compactMap { _, sessions -> SensorKitECGSession? in
                assert(sessions.count == 3)
                assert(sessions.mapIntoSet(\.state) == [.begin, .active, .end])
                guard let beginSession = sessions.first(where: { $0.state == .begin }),
                      let activeSession = sessions.first(where: { $0.state == .active }) else {
                    return nil
                }
                assert(
                    sessions.compactMapIntoSet { samplesBySession[$0]?.reduce(0) { $0 + $1.data.count } }.count { $0 > 0 } == 1
                ) // only one session should have samples?
                guard let samples = samplesBySession[activeSession]?.sorted(using: KeyPathComparator(\.date)), !samples.isEmpty else {
                    return nil
                }
                precondition(samples.mapIntoSet(\.lead).count == 1) // all samples should have same frequency?
                precondition(samples.mapIntoSet(\.frequency).count == 1) // all samples should have same frequency?
                precondition(samples.mapIntoSet(\.date).count == samples.count)
                // swiftlint:disable:next force_unwrapping
                let startDate = samplesBySession[beginSession]?.min(of: \.date) ?? samples.first!.date // we just sorted samples by date.
                return SensorKitECGSession(
                    startDate: startDate,
                    frequency: samples.first!.frequency, // swiftlint:disable:this force_unwrapping
                    lead: samples.first!.lead, // swiftlint:disable:this force_unwrapping
                    batches: samples.map { (sample: SRElectrocardiogramSample) -> SensorKitECGSession.Batch in
                        SensorKitECGSession.Batch(
                            offset: sample.date.timeIntervalSince(startDate),
                            samples: sample.data.map(SensorKitECGSession.Batch.VoltageSample.init)
                        )
                    }
                )
            }
        }
    }
}


// MARK: FHIR

extension SensorKitECGSession: HealthObservation {
    var sampleTypeIdentifier: String {
        Self.sensor.id
    }
    
    func resource( // swiftlint:disable:this function_body_length
        withMapping mapping: HKSampleMapping,
        issuedDate: FHIRPrimitive<Instant>?,
        extensions: [any FHIRExtensionBuilderProtocol]
    ) throws -> ResourceProxy {
        let ecgMapping = mapping.electrocardiogramMapping
        let observation = Observation(
            code: CodeableConcept(),
            status: FHIRPrimitive(.final)
        )
        observation.id = self.id.uuidString.asFHIRStringPrimitive()
        observation.appendIdentifier(Identifier(id: observation.id))
        if let issuedDate {
            observation.issued = issuedDate
        } else {
            try observation.setIssued(on: .now)
        }
        let ecgCodableConcept = CodeableConcept(
            coding: ecgMapping.codings.map { mappedCode -> Coding in
                Coding(
                    code: mappedCode.code.asFHIRStringPrimitive(),
                    display: mappedCode.display.asFHIRStringPrimitive(),
                    system: mappedCode.system.asFHIRURIPrimitive()
                )
            }
        )
        for coding in ecgCodableConcept.coding ?? [] {
            observation.appendCoding(coding)
        }
        for category in ecgMapping.categories {
            observation.appendCategory(
                CodeableConcept(coding: [
                    Coding(
                        code: category.code.asFHIRStringPrimitive(),
                        display: category.display.asFHIRStringPrimitive(),
                        system: category.system.asFHIRURIPrimitive()
                    )
                ])
            )
        }
        let precision = ecgMapping.voltagePrecision
        // "zero value and unit"
        let origin = Quantity(
            code: ecgMapping.voltageMeasurements.unit.code?.asFHIRStringPrimitive(),
            system: ecgMapping.voltageMeasurements.unit.system?.asFHIRURIPrimitive(),
            unit: ecgMapping.voltageMeasurements.unit.unit.asFHIRStringPrimitive(),
            value: 0.asFHIRDecimalPrimitive()
        )
        for batch in batches {
            observation.appendComponent(ObservationComponent(
                code: ecgCodableConcept,
                value: .sampledData(SampledData(
                    data: batch.samples.lazy.map { sample in
                        let value = sample.voltage.converted(to: .microvolts).value
                        return String(format: "%.\(precision)f", value)
                    }.joined(separator: " ").asFHIRStringPrimitive(), // swiftlint:disable:this multiline_function_chains
                    dimensions: 1,
                    lowerLimit: nil,
                    origin: origin,
                    period: ((1 / frequency.converted(to: .hertz).value) * 1000).asFHIRDecimalPrimitive(), // ms between samples
                    upperLimit: nil
                ))
            ))
        }
        for builder in extensions {
            try builder.apply(typeErasedInput: self, to: observation)
        }
        try observation.addMHCAppAsSource()
        return .observation(observation)
    }
}
