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


func measure<Result, E>(_ label: String = "", _ block: () throws(E) -> Result) throws(E) -> Result {
    let startTS = CACurrentMediaTime()
    defer {
        let endTS = CACurrentMediaTime()
        if !label.isEmpty {
            measureLogger.notice("[\(label)] \(endTS - startTS) sec")
        } else {
            measureLogger.notice("\(endTS - startTS) sec")
        }
    }
    return try block()
}


func measure<Result, E>(_ label: String = "", _ block: () async throws(E) -> Result) async throws(E) -> Result {
    let startTS = CACurrentMediaTime()
    defer {
        let endTS = CACurrentMediaTime()
        if !label.isEmpty {
            measureLogger.notice("[\(label)] \(endTS - startTS) sec")
        } else {
            measureLogger.notice("\(endTS - startTS) sec")
        }
    }
    return try await block()
}
