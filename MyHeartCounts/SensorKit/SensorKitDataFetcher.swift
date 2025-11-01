//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import OSLog
import Spezi
import SpeziFoundation
import SpeziSensorKit


@Observable
final class SensorKitDataFetcher: ServiceModule, EnvironmentAccessible, @unchecked Sendable {
    @Observable
    final class InProgressActivity: Hashable, Identifiable, AnyObjectBasedDefaultImpls, Sendable {
        nonisolated let sensor: any AnySensor
        @MainActor private(set) var timeRange: Range<Date>?
        @MainActor private(set) var message = ""
        
        nonisolated fileprivate init(sensor: any AnySensor) {
            self.sensor = sensor
        }
        
        nonisolated func updateMessage(_ newValue: String) {
            Task { @MainActor in
                self.message = newValue
            }
        }
        
        nonisolated func updateTimeRange(_ newValue: Range<Date>) {
            Task { @MainActor in
                self.timeRange = newValue
            }
        }
    }
    
    // swiftlint:disable attributes
    @ObservationIgnored @StandardActor private var standard: MyHeartCountsStandard
    @ObservationIgnored @Dependency(SensorKit.self) private var sensorKit
    @ObservationIgnored @Dependency(MHCBackgroundTasks.self) private var backgroundTasks
    @ObservationIgnored @Dependency(LocalNotifications.self) private var localNotifications
    @ObservationIgnored @Application(\.logger) private var logger
    // swiftlint:enable attributes
    
    /// The sensors that are currently being processed.
    @MainActor private(set) var activeActivities = Set<InProgressActivity>()
    
    
    nonisolated init() {}
    
    
    func run() async {
        Task(priority: .background) {
            for sensor in SensorKit.mhcSensors where sensor.authorizationStatus == .authorized {
                try? await sensor.startRecording()
            }
            await doFetch()
        }
    }
    
    
    @concurrent
    private func doFetch() async {
        await withManagedTaskQueue(limit: 2) { taskQueue in
            for uploadDefinition in SensorKit.mhcSensorUploadDefinitions {
                taskQueue.submit {
                    await self.fetchAndUploadAnchored(uploadDefinition)
                }
            }
        }
    }
    
    
    /// Fetches all new SensorKit samples for the specified sensor (relative to the last time the function was called for the sensor), and uploads them all into the Firestore.
    @concurrent
    private func fetchAndUploadAnchored(_ uploadDefinition: some AnyMHCSensorUploadDefinition<some Any, some Any>) async {
        let uploadDefinition = MHCSensorUploadDefinition(uploadDefinition)
        let sensor = uploadDefinition.sensor
        guard sensorKit.authorizationStatus(for: sensor) == .authorized else {
            logger.notice("Skipping Sensor '\(sensor.displayName)' bc it's not authorized.")
            return
        }
        logger.notice("Starting anchored fetch for SensorKit sensor '\(sensor.id)'")
        let activity = InProgressActivity(sensor: sensor)
        start(activity)
        defer {
            end(activity)
        }
        do {
            activity.updateMessage("Fetching Samples")
            for try await (batchInfo, batch) in try await sensorKit.fetchAnchored(sensor) {
                activity.updateTimeRange(batchInfo.timeRange)
                try await uploadDefinition.strategy.upload(batch, batchInfo: batchInfo, for: sensor, to: standard, activity: activity)
            }
        } catch {
            logger.error("Failed to fetch & upload data for Sensor '\(sensor.displayName)': \(error)")
        }
        logger.notice("Anchored fetch for '\(sensor.id)' is complete.")
    }
    
    // periphery:ignore
    /// Fetches all SensorKit samples for the specified sensor, and uploads them all into the Firestore.
    ///
    /// Primarily intended for testing purposes.
    @concurrent
    func fetchAndUploadAllSamples(for uploadDefinition: some AnyMHCSensorUploadDefinition<some Any, some Any>) async throws {
        let uploadDefinition = MHCSensorUploadDefinition(uploadDefinition)
        let sensor = uploadDefinition.sensor
        let activity = InProgressActivity(sensor: sensor)
        start(activity)
        defer {
            end(activity)
        }
        let devices = try await sensor.fetchDevices()
        for device in devices {
            let deviceInfo = SensorKit.DeviceInfo(device)
            let newestSampleDate = Date.now.addingTimeInterval(-sensor.dataQuarantineDuration.timeInterval)
            let oldestSampleDate = newestSampleDate.addingTimeInterval(-TimeConstants.day * 5.5)
            for startDate in stride(from: oldestSampleDate, through: newestSampleDate, by: sensor.suggestedBatchSize.timeInterval) {
                let timeRange = startDate..<min(startDate.addingTimeInterval(sensor.suggestedBatchSize.timeInterval), newestSampleDate)
                activity.updateTimeRange(timeRange)
                activity.updateMessage("Fetching Samples")
                let samples = (try? await sensor.fetch(from: device, timeRange: timeRange)) ?? []
                let batchInfo = SensorKit.BatchInfo(timeRange: timeRange, device: deviceInfo)
                try await uploadDefinition.strategy.upload(samples, batchInfo: batchInfo, for: sensor, to: standard, activity: activity)
            }
        }
    }
    
    /// Intended for debugging and development purposes
    func resetAllQueryAnchors() {
        func imp(_ sensor: some AnySensor) {
            let sensor = Sensor(sensor)
            try? sensorKit.resetQueryAnchor(for: sensor)
        }
        for sensor in SensorKit.allKnownSensors {
            imp(sensor)
        }
    }
    
    nonisolated private func start(_ activity: InProgressActivity) {
        Task { @MainActor in
            activeActivities.insert(activity)
        }
    }
    
    nonisolated private func end(_ activity: InProgressActivity) {
        Task { @MainActor in
            activeActivities.remove(activity)
        }
    }
}


extension MHCBackgroundTasks.TaskIdentifier {
    static let sensorKitProcessing = Self("edu.stanford.MyHeartCounts.SensorKitProcessing")
}


// MARK: Sensors

extension SensorKit {
    /// All sensors we want to enable automatic data collection for.
    static let mhcSensorUploadDefinitions: [any AnyMHCSensorUploadDefinition] = [
        MHCSensorUploadDefinition(sensor: .onWrist, strategy: UploadStrategyFHIRObservations()),
        MHCSensorUploadDefinition(sensor: .ecg, strategy: UploadStrategyFHIRObservations()),
        MHCSensorUploadDefinition(sensor: .wristTemperature, strategy: UploadStrategyCSVFile2()),
        MHCSensorUploadDefinition(sensor: .heartRate, strategy: UploadStrategyCSVFile()),
        MHCSensorUploadDefinition(sensor: .accelerometer, strategy: UploadStrategyCSVFile()),
        
        MHCSensorUploadDefinition(sensor: .ambientLight, strategy: UploadStrategyCSVFile()),
        MHCSensorUploadDefinition(sensor: .ambientPressure, strategy: UploadStrategyCSVFile()),
        MHCSensorUploadDefinition(sensor: .pedometer, strategy: UploadStrategyCSVFile()),
        MHCSensorUploadDefinition(sensor: .ppg, strategy: SRPhotoplethysmogramSample.UploadStrategy()),
        MHCSensorUploadDefinition(sensor: .deviceUsage, strategy: UploadStrategyFHIRObservations())
//        Sensor.visits
    ]
    
    static let mhcSensors: [any AnySensor] = mhcSensorUploadDefinitions.map { $0.typeErasedSensor }
    
    // periphery:ignore
    /// All sensors we technicall have access to.
    static let mhcSensorsExtended: [any AnySensor] = [
        Sensor.onWrist,
        Sensor.heartRate,
        Sensor.pedometer,
        Sensor.wristTemperature,
        Sensor.accelerometer,
        Sensor.ppg,
        Sensor.ecg,
        Sensor.ambientLight,
        Sensor.ambientPressure,
        Sensor.visits,
        Sensor.deviceUsage
    ]
}


extension ManagedFileUpload.Category {
    init(_ sensor: any AnySensor) {
        self.init(id: "SensorKitUpload/\(sensor.id)", title: "SensorKit \(sensor.displayName)", firebasePath: "SensorKit/\(sensor.id)")
    }
}
