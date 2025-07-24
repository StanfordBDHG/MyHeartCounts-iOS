//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import CoreMotion
import Foundation
@preconcurrency import SensorKit
import SpeziFoundation
import SpeziViews
import SwiftUI


struct SensorKitPlayground: View {
    @Environment(\.calendar) private var cal
    @Environment(SensorKit.self) private var sensorKit
    
    private let onWristReader = SensorReader(sensor: .onWrist)
    private let ambientLightReader = SensorReader(sensor: .ambientLight)
    private let ambientPressureReader = SensorReader(sensor: .ambientPressure)
    private let heartRateReader = SensorReader(sensor: .heartRate)
    private let pedometerReader = SensorReader(sensor: .pedometer)
    private let wristTemperatureReader = SensorReader(sensor: .wristTemperature)
    private let ppgReader = SensorReader(sensor: .ppg)
    private let ecgReader = SensorReader(sensor: .ecg)
    private let visitsReader = SensorReader(sensor: .visits)
    private let deviceUsageReader = SensorReader(sensor: .deviceUsage)
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        Form {
            Section {
                permissionsSection
            }
            Section {
                AsyncButton("Start All", state: $viewState) {
                    for sensor in allSensors {
                        try await sensor.startRecording()
                    }
                }
                AsyncButton("Stop All", state: $viewState) {
                    for sensor in allSensors {
                        try await sensor.stopRecording()
                    }
                }
            }
            Section("Sensors") {
                sensorReaderNavigationLink(for: onWristReader)
                sensorReaderNavigationLink(for: ambientLightReader)
                sensorReaderNavigationLink(for: ambientPressureReader)
                sensorReaderNavigationLink(for: heartRateReader)
                sensorReaderNavigationLink(for: pedometerReader)
                sensorReaderNavigationLink(for: wristTemperatureReader)
                sensorReaderNavigationLink(for: ppgReader)
                sensorReaderNavigationLink(for: ecgReader)
                sensorReaderNavigationLink(for: visitsReader)
                sensorReaderNavigationLink(for: deviceUsageReader)
            }
        }
        .viewStateAlert(state: $viewState)
    }
    
    
    @ViewBuilder private var permissionsSection: some View {
        AsyncButton("Request Permissions", state: $viewState) {
            try await sensorKit.requestAccess(to: [
                .onWristState,
                .heartRate,
                .pedometerData,
                .wristTemperature,
                .photoplethysmogram,
                .electrocardiogram,
                .ambientLightSensor,
                .ambientPressure,
                .visits,
                .deviceUsageReport
            ])
        }
        LabeledContent("Permissions", value: "n/a")
    }
    
    private var allSensors: [any SensorReaderProtocol] {
        [
            onWristReader,
            ambientLightReader,
            ambientPressureReader,
            heartRateReader,
            pedometerReader,
            wristTemperatureReader,
            ppgReader,
            ecgReader,
            visitsReader,
            deviceUsageReader
        ]
    }
    
    @ViewBuilder
    private func sensorReaderNavigationLink(for reader: SensorReader<some Any>) -> some View {
        NavigationLink(reader.sensor.displayName) {
            SensorReaderView(reader: reader)
        }
    }
}


extension SensorKitPlayground {
    private struct SensorReaderView<Sample: AnyObject & Hashable>: View {
        @Environment(\.calendar) private var cal
        let reader: SensorReader<Sample>
        @State private var viewState: ViewState = .idle
        @State private var devices: [SRDevice] = []
        @State private var didPerformInitialFetch = false
        @State private var fetchResults: [SensorKit.FetchResult<Sample>] = []
        @State private var numSamples: Int = 0
        @State private var coveredTimeRange: Range<Date>?
        
        var body: some View {
            Form {
                Section(reader.sensor.displayName) {
                    VStack(alignment: .leading) {
                        LabeledContent("#devices", value: devices.count, format: .number)
                        ForEach(devices, id: \.self) { device in
                            Text("- \(device.description)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    LabeledContent("#fetchResults", value: fetchResults.count, format: .number)
                    LabeledContent("#samples", value: fetchResults.reduce(0) { $0 + $1.count }, format: .number)
                }
                Section("Fetch Results") {
                    if viewState == .processing {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Fetching Data…")
                                Text("Depending on the amount of samples, this might take a bit")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        List(fetchResults/*.reversed().prefix(100)*/, id: \.self) { fetchResult in
                            NavigationLink {
                                FetchResultView(fetchResult: fetchResult)
                            } label: {
                                HStack {
                                    Text(fetchResult.sensorKitTimestamp, format: .iso8601)
                                    Spacer()
                                    if fetchResult.count == 1, let sample = fetchResult.first as? CMHighFrequencyHeartRateData {
                                        Text("\(sample.heartRate, format: .number) bpm")
                                    } else {
                                        Text("#=\(fetchResult.count)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
//            .navigationDestination(for: SensorKit.FetchResult<Sample>.self) { fetchResult in
//                FetchResultView(fetchResult: fetchResult)
//            }
            .navigationTitle(reader.sensor.displayName)
            .interactiveDismissDisabled(viewState == .processing)
            .navigationBarBackButtonHidden(viewState == .processing)
            .viewStateAlert(state: $viewState)
            .task {
                guard !didPerformInitialFetch else {
                    return
                }
                didPerformInitialFetch = true
                await fetchData()
            }
            .refreshable {
                Task {
                    await fetchData()
                }
            }
        }
        
        private func fetchData() async {
            guard viewState == .idle else {
                return
            }
            viewState = .processing
            fetchResults = []
            do {
                devices = try await reader.fetchDevices()
                var fetchResults: [SensorKit.FetchResult<Sample>] = []
                let timeRange = { () -> Range<Date> in
                    let end = cal.date(byAdding: .init(day: -1, minute: -10), to: .now)!
                    let start = cal.date(byAdding: .day, value: -6, to: end)!
                    return start..<end
                }()
                for device in devices {
                    fetchResults.append(contentsOf: try await reader.fetch(device: device, timeRange: timeRange))
                }
                if let firstResult = fetchResults.first {
                    var numSamples = firstResult.count
                    var totalTimeRange: Range<Date> = firstResult.sensorKitTimestamp..<firstResult.sensorKitTimestamp
                    for fetchResult in fetchResults.dropFirst() {
                        numSamples += fetchResult.count
                        totalTimeRange = min(totalTimeRange.lowerBound, fetchResult.sensorKitTimestamp)..<max(totalTimeRange.upperBound, fetchResult.sensorKitTimestamp)
                    }
                    self.numSamples = numSamples
                    self.coveredTimeRange = totalTimeRange
                }
                self.fetchResults = fetchResults.sorted(using: KeyPathComparator(\.sensorKitTimestamp, order: .reverse))
                viewState = .idle
            } catch {
                viewState = .error(error)
            }
        }
    }
    
    
    private struct FetchResultView<Sample: AnyObject & Hashable>: View {
        let fetchResult: SensorKit.FetchResult<Sample>
        
        var body: some View {
            Form {
                Section {
                    LabeledContent("SensorKit Timestamp", value: fetchResult.sensorKitTimestamp, format: .dateTime)
                }
                Section {
                    if let sample = fetchResult.first, fetchResult.count == 1 {
                        sampleFields(for: sample)
                    } else {
                        List(fetchResult, id: \.self) { sample in
                            NavigationLink {
                                Form {
                                    sampleFields(for: sample)
                                }
                            } label: {
                                Text("Sample") // TODO have more here?!
                            }
                        }
                    }
                }
            }
        }
        
        @ViewBuilder
        private func sampleFields(for sample: Sample) -> some View {
            switch sample {
            case let sample as SRAmbientLightSample:
                LabeledContent("placement", value: sample.placement.displayTitle)
                LabeledContent("chromaticity", value: "\(sample.chromaticity.x); \(sample.chromaticity.y)")
                LabeledContent("lux", value: sample.lux, format: .measurement(width: .abbreviated))
            case let sample as CMRecordedPressureData:
                LabeledContent("identifier", value: sample.identifier, format: .number)
                LabeledContent("startDate", value: sample.startDate, format: .iso8601)
                LabeledContent("pressure", value: sample.pressure, format: .measurement(width: .abbreviated))
                LabeledContent("temperature", value: sample.temperature, format: .measurement(width: .abbreviated))
                LabeledContent("timestamp", value: Date(timeIntervalSinceReferenceDate: sample.timestamp), format: .iso8601)
            case let sample as SRDeviceUsageReport:
                DeviceUsageReportView(report: sample)
            case let sample as CMHighFrequencyHeartRateData:
                LabeledContent("heartRate", value: sample.heartRate, format: .number)
                LabeledContent("conficence", value: sample.confidence.displayTitle)
                LabeledContent("date", value: (sample.date?.formatted()) ?? "n/a")
            default:
                Text("Unhandled sample type \(type(of: sample)) :/")
            }
        }
    }
}



extension CMHighFrequencyHeartRateDataConfidence {
    var displayTitle: String {
        switch self {
        case .low:
            "low"
        case .medium:
            "medium"
        case .high:
            "high"
        case .highest:
            "highest"
        @unknown default:
            "unknown<\(rawValue)>"
        }
    }
}




private struct DeviceUsageReportView: View {
    let report: SRDeviceUsageReport
    
    var body: some View {
        Section("Summarized") {
            LabeledContent("duration", value: report.duration, format: .timeInterval)
            LabeledContent("total screen wakes", value: report.totalScreenWakes, format: .number)
            LabeledContent("total unlocks", value: report.totalUnlocks, format: .number)
            LabeledContent("total unlock duration", value: report.totalUnlockDuration, format: .timeInterval)
        }
        Section("App Usage") {
            let categories = report.applicationUsageByCategory.keys.sorted(using: KeyPathComparator(\.rawValue))
            ForEach(categories, id: \.self) { (category: SRDeviceUsageReport.CategoryKey) in
                NavigationLink {
                    Form {
                        let usageData = report.applicationUsageByCategory[category] ?? []
                        ForEach(usageData, id: \.self) { (appUsage: SRDeviceUsageReport.ApplicationUsage) in
                            NavigationLink {
                                Form {
                                    LabeledContent("bundle id", value: appUsage.bundleIdentifier ?? "n/a")
                                    LabeledContent("reportApplicationIdentifier", value: appUsage.reportApplicationIdentifier)
                                    if !appUsage.supplementalCategories.isEmpty {
                                        Section("Supplemental Categories") {
                                            ForEach(appUsage.supplementalCategories, id: \.self) { (category: SRSupplementalCategory) in
                                                Text(category.identifier)
                                            }
                                        }
                                    }
                                    Section("Time Info") {
                                        LabeledContent("Usage Time", value: appUsage.usageTime, format: .timeInterval)
                                    }
                                }
                            } label: {
                                LabeledContent(appUsage.bundleIdentifier ?? "n/a", value: appUsage.usageTime, format: .timeInterval)
                            }
                        }
                    }
                } label: {
                    Text(category.rawValue)
                }
            }
        }
    }
}


extension TimeInterval {
    struct TimeIntervalFormatStyle: FormatStyle {
        func format(_ value: TimeInterval) -> String {
            let now = Date.now
            let range = now..<now.addingTimeInterval(value)
            return range.formatted(.timeDuration)
        }
    }
}


extension SRAmbientLightSample.SensorPlacement {
    var displayTitle: String {
        switch self {
        case .unknown:
            "unknown"
        case .frontTop:
            "frontTop"
        case .frontBottom:
            "frontBottom"
        case .frontRight:
            "frontRight"
        case .frontLeft:
            "frontLeft"
        case .frontTopRight:
            "frontTopRight"
        case .frontTopLeft:
            "frontTopLeft"
        case .frontBottomRight:
            "frontBottomRight"
        case .frontBottomLeft:
            "frontBottomLeft"
        @unknown default:
            "unknown<\(rawValue)>"
        }
    }
}


extension FormatStyle where Self == TimeInterval.TimeIntervalFormatStyle {
    static var timeInterval: Self {
        Self()
    }
}



@_silgen_name("swift_EnumCaseName")
func _getEnumCaseName<T>(_ value: T) -> UnsafePointer<CChar>?

func getEnumCaseName<T>(_ value: T) -> String? {
    if let stringPtr = _getEnumCaseName(value) {
        return String(validatingCString: stringPtr)
    }
    return nil
}
