//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
@preconcurrency import SensorKit
import Spezi
import SpeziHealthKit
import SpeziSensorKit


final class ECGExporter: Module {
    @Dependency(HealthKit.self)
    private var healthKit
    
    func configure() {
        Task {
            do {
                try await run()
            } catch {
                fatalError("\(error)")
            }
        }
    }
    
    
    private func run() async throws { // swiftlint:disable:this function_body_length
        let sensorKitSamples: [SRElectrocardiogramSample]
        do {
            let reader = SensorReader(.ecg)
            let devices = try await reader.fetchDevices()
            var fetchResults: [SensorKit.FetchResult<SRElectrocardiogramSample>] = []
            for device in devices {
                fetchResults.append(contentsOf: try await reader.fetch(from: device, mostRecentAvailable: .days(7)))
            }
            print(fetchResults.count, fetchResults.count(where: \.isEmpty))
            sensorKitSamples = fetchResults.flatMap(\.samples)
        }
        
        let healthKitSamples = try await healthKit.query(.electrocardiogram, timeRange: .last(days: 7))
        print(healthKitSamples)
        
        for sample in healthKitSamples {
            var csv = ""
            func addRow(key: some CustomStringConvertible, value: (some CustomStringConvertible)?) {
                csv += "\(key.description),\(value?.description ?? "")\n"
            }
            addRow(key: "Name", value: "Value")
            addRow(key: "id", value: sample.uuid)
            addRow(key: "Start", value: sample.startDate)
            addRow(key: "End", value: sample.endDate)
            addRow(key: "Classification", value: sample.classification.displayTitle)
            addRow(key: "Average Heart Rate", value: sample.averageHeartRate)
            addRow(key: "Symptoms Status", value: sample.symptomsStatus.displayTitle)
            for (symptom, severity) in try await sample.symptoms(from: healthKit) {
                addRow(key: "- \(symptom.identifier)", value: severity.displayTitle)
            }
            addRow(key: "Sampling Frequency", value: sample.samplingFrequency)
            addRow(key: "#voltageMeasurements", value: sample.numberOfVoltageMeasurements)
            for measurement in try await sample.voltageMeasurements(from: healthKit.healthStore) {
                addRow(key: "- \(measurement.timeOffset)", value: measurement.voltage)
            }
//            print("BEGIN\n\(csv)\nEND")
        }
        
        print(sensorKitSamples.mapIntoSet(\.session.identifier).count)
        
        do {
            var csv = ""
            func addRow<each Value: CustomStringConvertible>(key: some CustomStringConvertible, value: repeat each Value) {
                csv += key.description
                for value in repeat each value {
                    csv += ",\(value.description)"
                }
                csv += "\n"
            }
            addRow(key: "Name", value: "Value")
            for sample in sensorKitSamples.sorted(using: KeyPathComparator(\.date)) {
                for data in sample.data {
                    addRow(key: sample.date, value: data.value)
                }
            }
            print("BEGIN\n\(csv)\nEND")
        }
    }
}


extension SRElectrocardiogramData.Flags: @retroactive CustomStringConvertible {
    public var description: String {
        var descs: [String] = []
        if self.contains(.signalInvalid) {
            descs.append("invalid signal")
        }
        if self.contains(.crownTouched) {
            descs.append("crown touched")
        }
        return descs.joined(separator: ";")
    }
}


extension HKElectrocardiogram.Classification {
    var displayTitle: String {
        switch self {
        case .notSet:
            "notSet"
        case .sinusRhythm:
            "sinusRhythm"
        case .atrialFibrillation:
            "atrialFibrillation"
        case .inconclusiveLowHeartRate:
            "inconclusiveLowHeartRate"
        case .inconclusiveHighHeartRate:
            "inconclusiveHighHeartRate"
        case .inconclusivePoorReading:
            "inconclusivePoorReading"
        case .inconclusiveOther:
            "inconclusiveOther"
        case .unrecognized:
            "unrecognized"
        @unknown default:
            "unknown"
        }
    }
}

extension HKElectrocardiogram.SymptomsStatus {
    var displayTitle: String {
        switch self {
        case .notSet:
            "notSet"
        case .none:
            "none"
        case .present:
            "present"
        @unknown default:
            "unknown"
        }
    }
}


extension HKCategoryValueSeverity {
    var displayTitle: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .notPresent:
            "notPresent"
        case .mild:
            "mild"
        case .moderate:
            "moderate"
        case .severe:
            "severe"
        @unknown default:
            "unknown"
        }
    }
}
