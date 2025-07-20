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
    let srSensor: SRSensor
    let displayName: String
}

extension Sensor where Sample == SRWristDetection {
    static var onWrist: Sensor<SRWristDetection> {
        Sensor(srSensor: .onWristState, displayName: "On-Wrist State")
    }
}

extension Sensor where Sample == SRAmbientLightSample {
    static var ambientLight: Sensor<SRAmbientLightSample> {
        Sensor(srSensor: .ambientLightSensor, displayName: "Ambient Light")
    }
}

extension Sensor where Sample == CMRecordedPressureData {
    static var ambientPressure: Sensor<CMRecordedPressureData> {
        Sensor(srSensor: .ambientPressure, displayName: "Ambient Pressure")
    }
}

extension Sensor where Sample == CMHighFrequencyHeartRateData {
    static var heartRate: Sensor<CMHighFrequencyHeartRateData> {
        Sensor(srSensor: .heartRate, displayName: "Heart Rate")
    }
}

extension Sensor where Sample == CMPedometerData {
    static var pedometer: Sensor<CMPedometerData> {
        Sensor(srSensor: .pedometerData, displayName: "Pedometer")
    }
}

extension Sensor where Sample == SRWristTemperature {
    static var wristTemperature: Sensor<SRWristTemperature> {
        Sensor(srSensor: .wristTemperature, displayName: "Wrist Temperature")
    }
}

extension Sensor where Sample == SRPhotoplethysmogramSample {
    static var ppg: Sensor<SRPhotoplethysmogramSample> {
        Sensor(srSensor: .photoplethysmogram, displayName: "PPG")
    }
}

extension Sensor where Sample == SRElectrocardiogramSample {
    static var ecg: Sensor<SRElectrocardiogramSample> {
        Sensor(srSensor: .electrocardiogram, displayName: "ECG")
    }
}

extension Sensor where Sample == SRVisit {
    static var visits: Sensor<SRVisit> {
        Sensor(srSensor: .visits, displayName: "Visits")
    }
}

extension Sensor where Sample == SRDeviceUsageReport {
    static var deviceUsage: Sensor<SRDeviceUsageReport> {
        Sensor(srSensor: .deviceUsageReport, displayName: "Device Usage Report")
    }
}

// MARK: FetchedSample


struct FetchedSensorSample<Sample: AnyObject & Hashable>: @unchecked Sendable, Hashable { // ewww
    let sample: Sample
    let timestamp: SRAbsoluteTime
    
    fileprivate init(_ result: SRFetchResult<some Any>) {
        sample = result.sample as! Sample
        timestamp = result.timestamp
    }
}


// MARK: SensorReader

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
    func fetch(device: SRDevice?, timeRange: Range<Date>) async throws -> [FetchedSensorSample<Sample>]
}


final class SensorReader<Sample: AnyObject & Hashable>: NSObject, SensorReaderProtocol, @unchecked Sendable, SRSensorReaderDelegate {
    typealias FetchedSample = FetchedSensorSample<Sample>
    
    private enum State {
        case idle
        case fetchingDevices(CheckedContinuation<[SRDevice], any Error>)
        case fetchingSamples(samples: [FetchedSample], CheckedContinuation<[FetchedSample], any Error>)
        case startingRecording(CheckedContinuation<Void, any Error>)
        case stoppingRecording(CheckedContinuation<Void, any Error>)
        
        var isIdle: Bool {
            switch self {
            case .idle: true
            default: false
            }
        }
    }
    
    let sensor: Sensor<Sample>
    private let logger = Logger(subsystem: "edu.stanford.MHC", category: "SensorKit")
    private let reader: SRSensorReader
    /*@SensorKitActor*/ private var state: State = .idle
    
    var authorizationStatus: SRAuthorizationStatus {
        reader.authorizationStatus
    }
    
    init(sensor: Sensor<Sample>) {
        self.sensor = sensor
        reader = .init(sensor: sensor.srSensor)
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
    func fetchDevices() async throws -> sending [SRDevice] {
        checkIsIdle()
        defer {
            state = .idle
        }
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .fetchingDevices(continuation)
            reader.fetchDevices()
        }
    }
    
    @SensorKitActor
    func startRecording() async throws {
        checkIsIdle()
        defer {
            state = .idle
        }
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .startingRecording(continuation)
            reader.startRecording()
        }
    }
    
    @SensorKitActor
    func stopRecording() async throws {
        checkIsIdle()
        defer {
            state = .idle
        }
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .stoppingRecording(continuation)
            reader.stopRecording()
        }
    }
    
    @SensorKitActor
    func fetch(device: SRDevice? = nil, timeRange: Range<Date>) async throws -> [FetchedSample] { // TODO we could also model this as an API that returns an AsyncStream... (NOT A GOOD IDEA THOUGH!!!)
        checkIsIdle()
        let fetchRequest = SRFetchRequest()
        if let device {
            fetchRequest.device = device
        }
        //fetchRequest.from = .fromCFAbsoluteTime(_cf: timeRange.lowerBound.timeIntervalSinceReferenceDate)
        //fetchRequest.to = .fromCFAbsoluteTime(_cf: timeRange.upperBound.timeIntervalSinceReferenceDate)
        defer {
            state = .idle
        }
        return try await withCheckedThrowingContinuation { continuation in
            checkIsIdle()
            state = .fetchingSamples(samples: [], continuation)
            reader.fetch(fetchRequest)
        }
    }
    
    // MARK: SRSensorReaderDelegate
    
    func sensorReader(_ reader: SRSensorReader, didChange authorizationStatus: SRAuthorizationStatus) {
        logger.notice("sensorReaderDidChangeAuth \(reader) \(authorizationStatus.displayName)")
    }
    
    func sensorReader(_ reader: SRSensorReader, didFetch devices: [SRDevice]) {
        logger.notice("didFetchDevices \(reader) \(devices)")
        switch state {
        case .fetchingDevices(let continuation):
            nonisolated(unsafe) let devices = devices
            continuation.resume(returning: devices)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, fetchDevicesDidFailWithError error: any Error) {
        logger.notice("failedToFetchDevices \(reader) \(error)")
        switch state {
        case .fetchingDevices(let continuation):
            continuation.resume(throwing: error)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, fetching fetchRequest: SRFetchRequest, didFetchResult result: SRFetchResult<AnyObject>) -> Bool {
        logger.notice("didFetchResult \(fetchRequest) \(result)")
        switch state {
        case let .fetchingSamples(samples, continuation):
            state = .fetchingSamples(
                samples: samples.appending(contentsOf: CollectionOfOne(.init(result))),
                continuation
            )
        default:
            reportUnexpectedDelegateCallback()
        }
        return true
    }
    
    func sensorReader(_ reader: SRSensorReader, fetching fetchRequest: SRFetchRequest, failedWithError error: any Error) {
        logger.notice("fetchingFailed \(fetchRequest) \(error)")
        switch state {
        case .fetchingSamples(samples: _, let continuation):
            continuation.resume(throwing: error)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, didCompleteFetch fetchRequest: SRFetchRequest) {
        logger.notice("didCompleteFetch \(fetchRequest)")
        switch state {
        case let .fetchingSamples(samples, continuation):
            continuation.resume(returning: samples)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReaderWillStartRecording(_ reader: SRSensorReader) {
        logger.notice("willStartRecording \(reader)")
        switch state {
        case .startingRecording(let continuation):
            continuation.resume()
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, startRecordingFailedWithError error: any Error) {
        logger.notice("failedToStartRecording \(reader) \(error)")
        switch state {
        case .startingRecording(let continuation):
            continuation.resume(throwing: error)
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReaderDidStopRecording(_ reader: SRSensorReader) {
        logger.notice("didStopRecording \(reader)")
        switch state {
        case .stoppingRecording(let continuation):
            continuation.resume()
        default:
            reportUnexpectedDelegateCallback()
        }
    }
    
    func sensorReader(_ reader: SRSensorReader, stopRecordingFailedWithError error: any Error) {
        logger.notice("failedToStopRecording \(reader) \(error)")
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
