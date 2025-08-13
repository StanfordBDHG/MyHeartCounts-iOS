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
import SpeziSensorKit
import SpeziViews
import SwiftUI


struct SensorKitPlayground: View {
    @Environment(\.calendar) private var cal
    @Environment(SensorKit.self) private var sensorKit
    
    private let onWristReader = SensorReader(.onWrist)
    private let ambientLightReader = SensorReader(.ambientLight)
    private let ambientPressureReader = SensorReader(.ambientPressure)
    private let heartRateReader = SensorReader(.heartRate)
    private let pedometerReader = SensorReader(.pedometer)
//    private let wristTemperatureReader = SensorReader(.wristTemperature)
    private let ppgReader = SensorReader(.ppg)
    private let ecgReader = SensorReader(.ecg)
    private let visitsReader = SensorReader(.visits)
    private let deviceUsageReader = SensorReader(.deviceUsage)
    private let accelerometerReader = SensorReader(.accelerometer)
    
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
            AsyncButton("Fetch WristTemp Data", state: $viewState) {
                try await fetchWristTempData()
            }
            Section("Sensors") {
                sensorReaderNavigationLink(for: onWristReader)
                sensorReaderNavigationLink(for: ambientLightReader)
                sensorReaderNavigationLink(for: ambientPressureReader)
                sensorReaderNavigationLink(for: heartRateReader)
                sensorReaderNavigationLink(for: pedometerReader)
//                sensorReaderNavigationLink(for: wristTemperatureReader)
                sensorReaderNavigationLink(for: ppgReader)
                sensorReaderNavigationLink(for: ecgReader)
                sensorReaderNavigationLink(for: visitsReader)
                sensorReaderNavigationLink(for: deviceUsageReader)
                sensorReaderNavigationLink(for: accelerometerReader)
            }
        }
        .viewStateAlert(state: $viewState)
    }
    
    
    @ViewBuilder private var permissionsSection: some View {
        AsyncButton("Request Permissions", state: $viewState) {
            try await sensorKit.requestAccess(to: [
                Sensor.onWrist,
                Sensor.heartRate,
                Sensor.pedometer,
//                Sensor.wristTemperature,
                Sensor.accelerometer,
                Sensor.ppg,
                Sensor.ecg,
                Sensor.ambientLight,
                Sensor.ambientPressure,
                Sensor.visits,
                Sensor.deviceUsage
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
//            wristTemperatureReader,
            accelerometerReader,
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
    
    private nonisolated func fetchWristTempData() async throws {
        dispatchPrecondition(condition: .notOnQueue(.main))
        let reader = SensorReader(.wristTemperature)
        let devices = try await reader.fetchDevices()
        var sessions: [SRWristTemperatureSession] = []
        for device in devices {
            sessions.append(contentsOf: try await reader.fetch(from: device, mostRecentAvailable: .days(1)).flatMap(\.self))
        }
        print("#sessions: \(sessions.count)") // x
        for (idx, session) in sessions.enumerated() {
//            print("- [\(idx)]: \(session.startDate) \(session.temperatures.count(where: { _ in true }))")
            print(session)
            print(session.startDate, session.duration, session.version)
            print(type(of: session.temperatures))
            let samples: NSEnumerator = session.__temperatures
            while let sample = samples.nextObject() {
                print(sample)
            }
//            for sample in session.temperatures {
//                print(sample)
//            }
        }
        fatalError()
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
        @State private var filterEmptyFetchResults = false
        
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
                        let fetchResults = filterEmptyFetchResults ? fetchResults.filter { !$0.isEmpty } : fetchResults
                        List(fetchResults, id: \.self) { fetchResult in
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(isOn: $filterEmptyFetchResults.animation()) {
                            Text("Ignore Empty Fetch Results")
                        }
                    } label: {
                        Image(systemSymbol: filterEmptyFetchResults ? .line3HorizontalDecreaseCircleFill : .line3HorizontalDecreaseCircle)
                            .accessibilityLabel("Filter Options")
                    }
//                    Button {
//                        filterEmptyFetchResults.toggle()
//                    } label: {
//                        Image(systemSymbol: filterEmptyFetchResults ? .line3HorizontalDecreaseCircleFill : .line3HorizontalDecreaseCircle)
//                            .accessibilityLabel("Filter empty Fetch Results")
//                    }
                }
            }
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
                    let start = cal.date(byAdding: .day, value: -1, to: end)!
                    return start..<end
                }()
                for device in devices {
                    fetchResults.append(contentsOf: try await reader.fetch(from: device, timeRange: timeRange))
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
                        let _ = print(fetchResult.reduce(into: 0, { $0 ^ $1.hashValue }))
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
            case let sample as SRWristDetection:
                LabeledContent("onWrist", value: sample.onWrist.description)
                LabeledContent("wristLocation", value: sample.wristLocation.displayTitle)
                LabeledContent("crownOrientation", value: sample.crownOrientation.displayTitle)
                LabeledContent("onWristDate", value: sample.onWristDate?.formatted() ?? "n/a")
                LabeledContent("offWristDate", value: sample.offWristDate?.formatted() ?? "n/a")
            case let sample as SRVisit:
                LabeledContent("distanceFromHome", value: sample.distanceFromHome, format: .number) // TODO which unit is this?
                LabeledContent("arrivalDateInterval", value: sample.arrivalDateInterval, format: .humanReadable())
                LabeledContent("departureDateInterval", value: sample.departureDateInterval, format: .humanReadable())
                LabeledContent("locationCategory", value: sample.locationCategory.displayTitle)
                LabeledContent("identifier", value: sample.identifier.uuidString)
            case let sample as SRWristTemperatureSession:
                LabeledContent("startDate", value: sample.startDate, format: .dateTime)
                LabeledContent("duration", value: sample.duration, format: .timeInterval)
                LabeledContent("version", value: sample.version)
//                let measurements = Array(sample.temperatures)
                ForEach(Array(sample.temperatures), id: \.mhc_id) { (measurement: SRWristTemperature) in
//                    let measurement = measurements[idx]
                    HStack {
                        VStack(alignment: .leading) {
                            Text(measurement.timestamp, format: .dateTime)
                        }
                        Spacer()
                        Text(measurement.value, format: .measurement(width: .abbreviated))
                    }
                }
            default:
                Text("Unhandled sample type \(type(of: sample)) :/")
            }
        }
    }
}


extension SRWristTemperatureSession {
    var mhc_id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
    
//    public override func hash(into hasher: inout Hasher) {
//        hasher.combine(ObjectIdentifier(self))
//    }
}

extension SRWristTemperature {
    var mhc_id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}


extension SRVisit.LocationCategory {
    var displayTitle: String {
        switch self {
        case .unknown:
            "unknown"
        case .home:
            "home"
        case .work:
            "work"
        case .school:
            "school"
        case .gym:
            "gym"
        @unknown default:
            "unknown<\(rawValue)>"
        }
    }
}


extension SRWristDetection.WristLocation {
    var displayTitle: String {
        switch self {
        case .left:
            "left"
        case .right:
            "right"
        @unknown default:
            "unknown"
        }
    }
}


extension SRWristDetection.CrownOrientation {
    var displayTitle: String {
        switch self {
        case .left:
            "left"
        case .right:
            "right"
        @unknown default:
            "unknown"
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

extension FormatStyle where Self == TimeInterval.TimeIntervalFormatStyle {
    static var timeInterval: Self {
        Self()
    }
}


extension DateInterval {
    struct FormatStyleHumanReadable: FormatStyle {
        private let dateFormat: Date.FormatStyle
        private var locale: Locale
        
        init(dateFormat: Date.FormatStyle, locale: Locale = .current) {
            self.dateFormat = dateFormat
            self.locale = locale
        }
        
        func locale(_ locale: Locale) -> Self {
            var copy = self
            copy.locale = locale
            return copy
        }
        
        func format(_ value: DateInterval) -> String {
            let cal = locale.calendar
            var output = value.start.formatted(dateFormat)
            output.append(" – ")
            if cal.isDate(value.end, inSameDayAs: value.start) {
                output.append(value.end.formatted(dateFormat.omittingDate()))
            } else {
                output.append(value.end.formatted(dateFormat))
            }
            return output
        }
    }
}

extension FormatStyle where Self == DateInterval.FormatStyleHumanReadable {
    static func humanReadable(dateFormat: Date.FormatStyle = .init(), locale: Locale = .current) -> Self {
        Self(dateFormat: dateFormat, locale: locale)
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



@_silgen_name("swift_EnumCaseName")
func _getEnumCaseName<T>(_ value: T) -> UnsafePointer<CChar>?

func getEnumCaseName<T>(_ value: T) -> String? {
    if let stringPtr = _getEnumCaseName(value) {
        return String(validatingCString: stringPtr)
    }
    return nil
}
