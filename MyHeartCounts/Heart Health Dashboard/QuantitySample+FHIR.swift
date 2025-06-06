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
import SpeziHealthKit


extension QuantitySample: HealthObservation {
    enum FHIRObservationConversionError: Error {
        case notSupported
    }
    
    var sampleTypeIdentifier: String {
        self.sampleType.id
    }
    
    func resource(withMapping: HKSampleMapping, issuedDate: FHIRPrimitive<Instant>?) throws -> ResourceProxy {
        switch sampleType {
        case .custom(.bloodLipids):
            let observation = Observation(
                code: CodeableConcept(),
                status: FHIRPrimitive(.final)
            )
            // Set basic elements applicable to all observations
            observation.id = self.id.uuidString.asFHIRStringPrimitive()
            observation.appendIdentifier(Identifier(id: observation.id))
            try observation.setEffective(startDate: self.startDate, endDate: self.endDate, timeZone: .current)
            if let issuedDate {
                observation.issued = issuedDate
            } else {
                try observation.setIssued(on: .now)
            }
            let code = "18262-6".asFHIRStringPrimitive() // "Cholesterol in LDL [Mass/volume] in Serum or Plasma by Direct assay"
            let system = "http://loinc.org".asFHIRURIPrimitive()
            observation.appendCodings([
                Coding(code: code, system: system),
                Coding(
                    code: sampleType.id.asFHIRStringPrimitive(),
                    display: sampleType.displayTitle.asFHIRStringPrimitive(),
                    system: "https://spezi.stanford.edu".asFHIRURIPrimitive()
                )
            ])
            observation.value = .quantity(Quantity(
                code: code,
                system: system,
                unit: "mg/dL".asFHIRStringPrimitive(),
                value: value.asFHIRDecimalPrimitive()
            ))
            return .observation(observation)
        default:
            throw FHIRObservationConversionError.notSupported
        }
    }
}


extension QuantitySample {
    init?(_ resourceProxy: ModelsR4.ResourceProxy) {
        switch resourceProxy {
        case .observation(let observation):
            if let sample = Self(observation) {
                self = sample
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    /// Attempts to create a ``QuantitySample`` from a FHIR `Observation`.
    ///
    /// - parameter sampleTypeHint: the expected sample type. if you specify `nil`, the function will attempt to determine the sample type automatically, based on the Observation.
    init?(_ observation: ModelsR4.Observation, sampleTypeHint: MHCQuantitySampleType? = nil) { // swiftlint:disable:this function_body_length
        guard let id = (observation.id?.value?.string).flatMap({ UUID(uuidString: $0) }),
              case .quantity(let quantity) = observation.value,
              let rawUnit = quantity.unit?.value?.string,
              let value = (quantity.value?.value?.decimal).map({ Double($0) }),
              let effective = observation.effective,
              let coding = observation.code.coding else {
            print(#line)
            return nil
        }
        let startDate: Date
        let endDate: Date
        switch effective {
        case .dateTime(let dateTime):
            guard let date = try? dateTime.value?.asNSDate() else {
                print(#line)
                return nil
            }
            startDate = date
            endDate = date
        case .instant(let instant):
            guard let date = try? instant.value?.asNSDate() else {
                print(#line)
                return nil
            }
            startDate = date
            endDate = date
        case .period(let period):
            guard let start = try? period.start?.value?.asNSDate(),
                  let end = try? period.end?.value?.asNSDate() else {
                print(#line)
                return nil
            }
            startDate = start
            endDate = end
        case .timing:
            print(#line)
            return nil
        }
        let sampleType: MHCQuantitySampleType
        if let sampleTypeHint {
            sampleType = sampleTypeHint
        } else if let healthKitCoding = coding.first(where: { $0.system == "http://developer.apple.com/documentation/healthkit" }) {
            guard let sampleTypeIdentifier = healthKitCoding.code?.value?.string,
                  let healthKitSampleType = SpeziHealthKit.SampleType<HKQuantitySample>(.init(rawValue: sampleTypeIdentifier)) else {
                print(#line)
                return nil
            }
            sampleType = .healthKit(healthKitSampleType)
        } else if let mhcCustomTypeCoding = coding.first(where: { $0.system == "https://spezi.stanford.edu" }),
                  let identifier = mhcCustomTypeCoding.code?.value?.string,
                  let mhcSampleType = CustomQuantitySampleType(identifier: identifier) {
            sampleType = .custom(mhcSampleType)
        } else {
            // no hint and also we were unable to extract smth we know / can handle
            print(#line)
            return nil
        }
        self.init(
            id: id,
            sampleType: sampleType,
            unit: HKUnit(from: rawUnit),
            value: value,
            startDate: startDate,
            endDate: endDate
        )
    }
}
