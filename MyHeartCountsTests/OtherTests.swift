//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable line_length

import Foundation
@testable import MyHeartCounts
import Testing


@Suite(.tags(.unitTest))
struct OtherTests {
    @Test
    func makeNoon() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        
        do {
            let date1 = try #require(cal.date(from: .init(year: 2025, month: 5, day: 24, hour: 7, minute: 6, second: 44, nanosecond: Int(1e9 * 0.2320943))))
            #expect(date1.timeIntervalSinceReferenceDate == 769763204.2320943)
            #expect(date1.timeIntervalSinceReferenceDate - 769763204.2320943 == 0)
            let date2 = try #require(cal.date(from: .init(year: 2025, month: 5, day: 24, hour: 12, minute: 0, second: 0)))
            #expect(cal.makeNoon(date1) == date2)
        }
        
        do {
            let date1 = try #require(cal.date(from: .init(year: 2025, month: 5, day: 25, hour: 3, minute: 49, second: 27, nanosecond: Int(1e9 * 0.886064))))
            #expect(date1.timeIntervalSinceReferenceDate == 769837767.886064)
            #expect(date1.timeIntervalSinceReferenceDate - 769837767.886064 == 0)
            let date2 = try #require(cal.date(from: .init(year: 2025, month: 5, day: 25, hour: 12, minute: 0, second: 0)))
            #expect(cal.makeNoon(date1) == date2)
        }
        
        do {
            let date1 = Date(timeIntervalSinceReferenceDate: 769763204.2320942)
            let date2 = try #require(cal.date(from: .init(year: 2025, month: 5, day: 24, hour: 12, minute: 0, second: 0)))
            #expect(cal.makeNoon(date1) == date2)
        }
        
        do {
            let date1 = Date(timeIntervalSinceReferenceDate: 769837767.886064)
            let date2 = try #require(cal.date(from: .init(year: 2025, month: 5, day: 25, hour: 12, minute: 0, second: 0)))
            #expect(cal.makeNoon(date1) == date2)
        }
    }
}
