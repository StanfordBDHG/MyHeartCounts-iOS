//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable no_extension_access_modifier all

import CoreMotion
import Foundation
import os
/*@preconcurrency*/ import SensorKit
import Spezi


@Observable
@MainActor
final class SensorKit: Module, EnvironmentAccessible {
    nonisolated private let logger = Logger(subsystem: "edu.stanford.MHC", category: "SensorKit")
}


// MARK: Authorization

nonisolated extension SensorKit {
//    @SensorKitActor
    func authorizationStatus(for sensor: SRSensor) -> SRAuthorizationStatus {
        let reader = SRSensorReader(sensor: sensor)
        return reader.authorizationStatus
    }
    
    @MainActor
    func requestAccess(to sensors: Set<SRSensor>) async throws {
        do {
            try await SRSensorReader.requestAuthorization(sensors: sensors)
        } catch {
            if (error as? SRError)?.code == .promptDeclined,
               (error as NSError).underlyingErrors.contains(where: { ($0 as NSError).code == 8201 }) {
                // the request failed bc we're already authenticated.
                return
            } else {
                throw error
            }
        }
    }
    
    
//    func fetch(_ sensor: SRSensor) async throws -> Any {
//        let reader = SensorReader(sensor: sensor)
//    }
}


// MARK: Sensor

struct Sensor<Sample: AnyObject & Hashable>: Hashable, Sendable {
    /// The underlying SensorKit `SRSensor`
    let srSensor: SRSensor
    /// The recommended display name
    let displayName: String
    /// How long the system hold data in quarantine before it can be queried by applications.
    let dataQuarantineDuration: Duration
}

extension Sensor where Sample == SRWristDetection {
    static var onWrist: Sensor<SRWristDetection> {
        Sensor(
            srSensor: .onWristState,
            displayName: "On-Wrist State",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == SRAmbientLightSample {
    static var ambientLight: Sensor<SRAmbientLightSample> {
        Sensor(
            srSensor: .ambientLightSensor,
            displayName: "Ambient Light",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == CMRecordedPressureData {
    static var ambientPressure: Sensor<CMRecordedPressureData> {
        Sensor(
            srSensor: .ambientPressure,
            displayName: "Ambient Pressure",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == CMHighFrequencyHeartRateData {
    static var heartRate: Sensor<CMHighFrequencyHeartRateData> {
        Sensor(
            srSensor: .heartRate,
            displayName: "Heart Rate",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == CMPedometerData {
    static var pedometer: Sensor<CMPedometerData> {
        Sensor(
            srSensor: .pedometerData,
            displayName: "Pedometer",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == SRWristTemperatureSession {
    static var wristTemperature: Sensor<SRWristTemperatureSession> {
        Sensor(
            srSensor: .wristTemperature,
            displayName: "Wrist Temperature",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == SRPhotoplethysmogramSample {
    static var ppg: Sensor<SRPhotoplethysmogramSample> {
        Sensor(
            srSensor: .photoplethysmogram,
            displayName: "PPG",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == SRElectrocardiogramSample {
    static var ecg: Sensor<SRElectrocardiogramSample> {
        Sensor(
            srSensor: .electrocardiogram,
            displayName: "ECG",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == SRVisit {
    static var visits: Sensor<SRVisit> {
        Sensor(
            srSensor: .visits,
            displayName: "Visits",
            dataQuarantineDuration: .hours(24)
        )
    }
}

extension Sensor where Sample == SRDeviceUsageReport {
    static var deviceUsage: Sensor<SRDeviceUsageReport> {
        Sensor(
            srSensor: .deviceUsageReport,
            displayName: "Device Usage Report",
            dataQuarantineDuration: .hours(24)
        )
    }
}

// MARK: FetchedSample


extension SensorKit {
    struct FetchResult<Sample: AnyObject & Hashable>: Hashable, @unchecked Sendable {
        /// The SensorKit framework's timestamp
        let sensorKitTimestamp: Date
        let samples: [Sample]
        
        init(_ fetchResult: SRFetchResult<AnyObject>) {
            sensorKitTimestamp = Date(timeIntervalSinceReferenceDate: fetchResult.timestamp.toCFAbsoluteTime())
            samples = if let samples = fetchResult.sample as? [Sample] {
                samples
            } else if let sample = fetchResult.sample as? Sample {
                [sample]
            } else {
                preconditionFailure("Unable to process fetch result \(fetchResult)")
            }
        }
    }
}


extension SensorKit.FetchResult: RandomAccessCollection {
    var startIndex: Int {
        samples.startIndex
    }
    var endIndex: Int {
        samples.endIndex
    }
    subscript(position: Int) -> Sample {
        samples[position]
    }
}


// MARK: SensorReader

//extension SensorKit {
//    enum FetchError: Error {
//        case invalidTimeRange
//    }
//}

protocol SensorReaderProtocol<Sample>: AnyObject, Sendable {
    associatedtype Sample: AnyObject & Hashable
    
    var sensor: Sensor<Sample> { get }
    
    @SensorKitActor
    func startRecording() async throws
    
    @SensorKitActor
    func stopRecording() async throws
    
    @SensorKitActor
    func fetchDevices() async throws -> sending [SRDevice]
    
    @SensorKitActor
    func fetch(from device: SRDevice?, timeRange: Range<Date>) async throws -> [SensorKit.FetchResult<Sample>]
}


extension SensorReaderProtocol {
    @SensorKitActor
    func fetch(from device: SRDevice? = nil, mostRecentAvailable fetchDuration: Duration) async throws -> [SensorKit.FetchResult<Sample>] {
        let endDate = Date.now.addingTimeInterval(-sensor.dataQuarantineDuration.timeInterval)
        let startDate = endDate.addingTimeInterval(-fetchDuration.timeInterval)
        return try await fetch(from: device, timeRange: startDate..<endDate)
    }
}



@Observable
final class SensorReader<Sample: AnyObject & Hashable>: NSObject, SensorReaderProtocol, @unchecked Sendable, SRSensorReaderDelegate {
    private enum State {
        case idle
        case fetchingDevices(CheckedContinuation<[SRDevice], any Error>)
        case fetchingSamples(samples: [SensorKit.FetchResult<Sample>], CheckedContinuation<[SensorKit.FetchResult<Sample>], any Error>)
        case startingRecording(CheckedContinuation<Void, any Error>)
        case stoppingRecording(CheckedContinuation<Void, any Error>)
        
        var isIdle: Bool {
            switch self {
            case .idle: true
            default: false
            }
        }
    }
    
    private final class Lock {
        private var isLocked = false
        private var waiters: [CheckedContinuation<Void, Never>] = []
        
        init() {}
        
        func lock() async {
            if !isLocked {
                precondition(waiters.isEmpty, "invalid state: lock is open but there are waiters.")
                isLocked = true
            } else {
                // the lock is locked.
                // we need to wait until it is our turn to obtain the lock.
                await withCheckedContinuation { continuation in
                    waiters.append(continuation)
                }
            }
        }
        
        func unlock() {
            precondition(isLocked, "invalid state: cannot unlock lock that isn't locked.")
            if waiters.isEmpty {
                // no one wants to take the lock over from us; we can simply open it
                isLocked = false
            } else {
                // if there are waiters, we keep the lock closed and (semantially) hand it over to the first continuation.
                waiters.removeFirst().resume()
            }
        }
    }
    
    @ObservationIgnored let sensor: Sensor<Sample>
    @ObservationIgnored private let logger = Logger(subsystem: "edu.stanford.MHC", category: "SensorKit")
    @ObservationIgnored private let reader: SRSensorReader
    @ObservationIgnored /*@SensorKitActor*/ private var state: State = .idle
    @ObservationIgnored @SensorKitActor private let lock = Lock()
    @MainActor private(set) var authorizationStatus: SRAuthorizationStatus = .notDetermined
    
    nonisolated init(sensor: Sensor<Sample>) {
        self.sensor = sensor
        reader = SRSensorReader(sensor: sensor.srSensor)
//        id = "123"
        super.init()
        reader.delegate = self
    }
    
    deinit {
        logger.notice("\(self.reader) DEINIT")
    }
    
    @SensorKitActor
    private func checkIsIdle() {
        precondition(state.isIdle)
    }
    
    @SensorKitActor
    private func lock() async {
        await lock.lock()
    }
    
    @SensorKitActor
    private func unlock() {
        lock.unlock()
    }
    
    @SensorKitActor
    func fetchDevices() async throws -> sending [SRDevice] {
        await lock()
        checkIsIdle()
        defer {
            state = .idle
            unlock()
        }
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .fetchingDevices(continuation)
            reader.fetchDevices()
        }
    }
    
    @SensorKitActor
    func startRecording() async throws {
        await lock()
        checkIsIdle()
        defer {
            state = .idle
            unlock()
        }
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .startingRecording(continuation)
            reader.startRecording()
        }
    }
    
    @SensorKitActor
    func stopRecording() async throws {
        await lock()
        checkIsIdle()
        defer {
            state = .idle
            unlock()
        }
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .stoppingRecording(continuation)
            reader.stopRecording()
        }
    }
    
    @SensorKitActor
    func fetch(from device: SRDevice? = nil, timeRange: Range<Date>) async throws -> [SensorKit.FetchResult<Sample>] { // TODO we could also model this as an API that returns an AsyncStream... (NOT A GOOD IDEA THOUGH!!!)
        logger.notice("Will obtain lock to perform fetch")
        await lock()
        logger.notice(" Did obtain lock to perform fetch")
        checkIsIdle()
        defer {
            state = .idle
            logger.notice("Will release lock")
            unlock()
            logger.notice(" Did release lock")
        }
        let fetchRequest = SRFetchRequest()
        if let device {
            fetchRequest.device = device
        }
        fetchRequest.from = .fromCFAbsoluteTime(_cf: timeRange.lowerBound.timeIntervalSinceReferenceDate)
        fetchRequest.to = .fromCFAbsoluteTime(_cf: timeRange.upperBound.timeIntervalSinceReferenceDate)
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .fetchingSamples(samples: [], continuation)
            reader.fetch(fetchRequest)
        }
    }
    
    // MARK: SRSensorReaderDelegate
    
    func sensorReader(_ reader: SRSensorReader, didChange authorizationStatus: SRAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = authorizationStatus
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, didFetch devices: [SRDevice]) {
        switch state {
        case .fetchingDevices(let continuation):
            nonisolated(unsafe) let devices = devices
            continuation.resume(returning: devices)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, fetchDevicesDidFailWithError error: any Error) {
        switch state {
        case .fetchingDevices(let continuation):
            continuation.resume(throwing: error)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, fetching fetchRequest: SRFetchRequest, didFetchResult result: SRFetchResult<AnyObject>) -> Bool {
        switch state {
        case let .fetchingSamples(samples, continuation):
            var samples = consume samples
            samples.append(.init(result))
            state = .fetchingSamples(samples: samples, continuation)
        default:
            reportUnexpectedDelegateCallback()
        }
        return true
    }
    
    func sensorReader(_ reader: SRSensorReader, fetching fetchRequest: SRFetchRequest, failedWithError error: any Error) {
        switch state {
        case .fetchingSamples(samples: _, let continuation):
            continuation.resume(throwing: error)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, didCompleteFetch fetchRequest: SRFetchRequest) {
        switch state {
        case let .fetchingSamples(samples, continuation):
            continuation.resume(returning: samples)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReaderWillStartRecording(_ reader: SRSensorReader) {
        switch state {
        case .startingRecording(let continuation):
            continuation.resume()
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, startRecordingFailedWithError error: any Error) {
        switch state {
        case .startingRecording(let continuation):
            continuation.resume(throwing: error)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReaderDidStopRecording(_ reader: SRSensorReader) {
        switch state {
        case .stoppingRecording(let continuation):
            continuation.resume()
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, stopRecordingFailedWithError error: any Error) {
        switch state {
        case .stoppingRecording(let continuation):
            continuation.resume(throwing: error)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    private func reportUnexpectedDelegateCallback(_ caller: StaticString = #function) {
        guard state.isIdle else {
            fatalError()
        }
        logger.error("Unexpectedly received delegate callback '\(caller)' while in idle state.")
    }
}


extension SRAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            "not determined"
        case .authorized:
            "authorized"
        case .denied:
            "denied"
        @unknown default:
            "unknown<\(rawValue)>"
        }
    }
}
