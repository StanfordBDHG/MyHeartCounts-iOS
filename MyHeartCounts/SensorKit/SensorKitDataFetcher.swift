//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import BackgroundTasks
import HealthKitOnFHIR
import OSLog
import Spezi
import SpeziFoundation
import SpeziHealthKit
import SpeziSensorKit
import UserNotifications
import struct ModelsR4.FHIRPrimitive
import struct ModelsR4.Instant


final class SensorKitDataFetcher: ServiceModule, EnvironmentAccessible, @unchecked Sendable {
    static let logger = Logger(subsystem: "edu.stanford.MyHeartCounts", category: "SensorKitDataFetcher")
    
    // swiftlint:disable attributes
    @StandardActor private var standard: MyHeartCountsStandard
    @Dependency(SensorKit.self) private var sensorKit
    @Dependency(HealthKit.self) private var healthKit
    @Dependency(MHCBackgroundTasks.self) private var backgroundTasks
    @Dependency(LocalNotifications.self) private var localNotifications
    private var logger: Logger { Self.logger }
    // swiftlint:enable attributes
    
    func configure() {
        do {
            try backgroundTasks.register(.healthResearch(
                id: .sensorKitProcessing,
                earliest: nil,
                options: [],
                protectionTypeOfRequiredData: .none
            ) { () async throws in
                try await self.localNotifications.send(title: "SensorKit", body: "Did start background task")
            })
        } catch {
            logger.error("Unable to register background task: \(error)")
        }
    }
    
    func run() async {
        Task(priority: .background) {
            for sensor in SensorKit.mhcSensors where sensor.authorizationStatus == .authorized {
                try? await sensor.startRecording()
            }
            await doFetch()
        }
        
//        Task {
//            let sensor = Sensor.ppg
//            let devices = try await sensor.fetchDevices()
//            for device in devices {
//                logger.notice("- DEVICE: \(device)")
//            }
//            let cal = Calendar.current
//            let start = cal.date(from: .init(timeZone: .current, year: 2025, month: 10, day: 21, hour: 0))!
//            let end = cal.date(from: .init(timeZone: .current, year: 2025, month: 10, day: 22, hour: 0))!
//            for device in devices {
//                let samples = try await sensor.fetch(from: device, timeRange: start..<end)
//                logger.notice("#samples: \(samples.count)")
//            }
//            fatalError()
//        }
        
        
//        Task {
////            try! await fetchAndUploadAllSamples(for: MHCSensorUploadDefinition(sensor: .ambientLight, strategy: UploadStrategyCSVFile()))
//            try! await fetchAndUploadAllSamples(for: MHCSensorUploadDefinition(sensor: .ecg, strategy: UploadStrategyFHIRObservations()))
//            try! await fetchAndUploadAllSamples(for: MHCSensorUploadDefinition(sensor: .onWrist, strategy: UploadStrategyFHIRObservations()))
//        }
    }
    
    
    @concurrent
    private func doFetch() async {
        await withDiscardingTaskGroup { taskGroup in
            for uploadDefinition in SensorKit.mhcSensorUploadDefinitions {
                taskGroup.addTask {
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
        do {
            logger.notice("will fetch new samples for Sensor '\(sensor.displayName)'")
            for try await (deviceInfo, batch) in try await sensorKit.fetchAnchored(sensor) {
                logger.notice("\(batch.count) new sample(s) for \(sensor.displayName)")
                try await uploadDefinition.strategy.upload(batch, from: deviceInfo, for: sensor, to: standard)
            }
        } catch {
            logger.error("Failed to fetch & upload data for Sensor '\(sensor.displayName)': \(error)")
        }
    }
    
    // periphery:ignore
    /// Fetches all SensorKit samples for the specified sensor, and uploads them all into the Firestore.
    ///
    /// Primarily intended for testing purposes.
    @concurrent
    func fetchAndUploadAllSamples(for uploadDefinition: some AnyMHCSensorUploadDefinition<some Any, some Any>) async throws {
        let uploadDefinition = MHCSensorUploadDefinition(uploadDefinition)
        let sensor = uploadDefinition.sensor
        let devices = try await sensor.fetchDevices()
        for device in devices {
            let deviceInfo = SensorKit.DeviceInfo(device)
            let newestSampleDate = Date.now.addingTimeInterval(-sensor.dataQuarantineDuration.timeInterval)
            let oldestSampleDate = newestSampleDate.addingTimeInterval(-TimeConstants.day * 5.5)
            for startDate in stride(from: oldestSampleDate, through: newestSampleDate, by: sensor.suggestedBatchSize.timeInterval) {
                let timeRange = startDate..<min(startDate.addingTimeInterval(sensor.suggestedBatchSize.timeInterval), newestSampleDate)
                let samples = (try? await sensor.fetch(from: device, timeRange: timeRange)) ?? []
                self.logger.notice("Submitting \(samples.count) samples for uploading")
                try await uploadDefinition.strategy.upload(samples, from: deviceInfo, for: sensor, to: standard)
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
}


extension MHCBackgroundTasks.TaskIdentifier {
    static let sensorKitProcessing = Self(rawValue: "edu.stanford.MyHeartCounts.SensorKitProcessing")
}


// MARK: Sensors

extension SensorKit {
    /// All sensors we want to enable continuous data collection for.
    static let mhcSensorUploadDefinitions: [any AnyMHCSensorUploadDefinition] = [
        MHCSensorUploadDefinition(sensor: .onWrist, strategy: UploadStrategyFHIRObservations()),
        MHCSensorUploadDefinition(sensor: .ecg, strategy: UploadStrategyFHIRObservations()),
//        MHCSensorUploadDefinition(sensor: .wristTemperature, strategy: UploadStrategyFHIRObservations()),
        
        MHCSensorUploadDefinition(sensor: .ambientLight, strategy: UploadStrategyCSVFile()),
        MHCSensorUploadDefinition(sensor: .ambientPressure, strategy: UploadStrategyCSVFile()),
//        Sensor.visits,
//        Sensor.pedometer,
//        Sensor.ppg,
//        Sensor.wristTemperature
    ]
    
    static let mhcSensors: [any AnySensor] = mhcSensorUploadDefinitions.map { $0.typeErasedSensor }
    
    // periphery:ignore
    /// All sensors we officially support.
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
