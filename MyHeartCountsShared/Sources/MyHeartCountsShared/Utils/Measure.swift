//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import func QuartzCore.CACurrentMediaTime


private let measureLogger = Logger(category: .init("measure"))


/// Measures the duration of an operation
public func measure<Result, E, C: Clock>(
    clock: C = ContinuousClock(),
    _ label: @autoclosure () -> String = "",
    _ action: () throws(E) -> Result
) throws(E) -> Result where C.Instant.Duration == Duration {
    let start = clock.now
    let result = try action()
    let end = clock.now
    let label = label()
    if !label.isEmpty {
        measureLogger.debug("[\(label)] \(start.duration(to: end)) sec")
    } else {
        measureLogger.notice("\(start.duration(to: end)) sec")
    }
    return result
}


/// Measures the duration of an asynchronous operation
public func measure<Result, E, C: Clock>(
    clock: C = ContinuousClock(),
    _ label: @autoclosure () -> String = "",
    _ action: () async throws(E) -> Result
) async throws(E) -> Result where C.Instant.Duration == Duration {
    let start = clock.now
    let result = try await action()
    let end = clock.now
    let label = label()
    if !label.isEmpty {
        measureLogger.debug("[\(label)] \(start.duration(to: end)) sec")
    } else {
        measureLogger.notice("\(start.duration(to: end)) sec")
    }
    return result
}
