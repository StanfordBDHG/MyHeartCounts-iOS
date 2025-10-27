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
import OSLog
import Spezi
import SpeziFoundation


@MainActor
final class MotionDataFetcher: Module, Sendable {
    @Application(\.logger) private var logger
    
    private let motionManager = CMMotionManager()
    
    
    func configure() {
        Task {
            guard await CMMotionManager.requestMotionDataAccess() else {
                self.logger.notice("Denied motion access :/")
                return
            }
            try await self.doStuff()
        }
    }
    
    
    private func doStuff() async throws {
        let cal = Calendar.current
        let timeRange = cal.rangeOfDay(for: cal.startOfPrevDay(for: .now))
        let data = try await CMPedometer().query(for: timeRange)
        print("PEDOMETER DATA", data)
    }
}


extension CMPedometer {
    func query(for timeRange: Range<Date>) async throws -> sending CMPedometerData {
        try await withCheckedThrowingContinuation { continuation in
            self.queryPedometerData(from: timeRange.lowerBound, to: timeRange.upperBound) { @Sendable data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    nonisolated(unsafe) let data = data!
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
