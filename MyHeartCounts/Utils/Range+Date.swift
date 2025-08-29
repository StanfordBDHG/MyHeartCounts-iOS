//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


extension Range where Bound == Date {
    func displayText(using cal: Calendar) -> String {
        // would it maybe make sense to have a "TimeRangeLabel"?
        // certainly space for improvement here...
        if self == cal.rangeOfDay(for: .now) {
            return String(localized: "Today")
        } else if self == cal.rangeOfDay(for: cal.startOfPrevDay(for: .now)) {
            return String(localized: "Yesterday")
        } else if self == cal.rangeOfDay(for: self.lowerBound) {
            return "\(self.lowerBound.formatted(date: .abbreviated, time: .omitted))"
        } else if self.isEmpty, case let date = self.lowerBound { // startDate == endDate
            return if cal.isDateInToday(date) && date <= .now {
                "\(date.formatted(date: .omitted, time: .shortened))"
            } else {
                // is older than today
                "\(date.formatted(date: .numeric, time: .shortened))"
            }
        } else if cal.isDate(lowerBound, inSameDayAs: upperBound) {
            if cal.isDateInToday(upperBound) {
                return String(localized: "Today")
            } else if cal.isDateInYesterday(upperBound) {
                return String(localized: "Yesterday")
            } else {
                return "\(lowerBound.formatted(date: .abbreviated, time: .omitted))"
            }
        } else {
            let fmt = { ($0 as Date).formatted(date: .abbreviated, time: .omitted) }
            return "\(fmt(self.lowerBound)) – \(fmt(self.upperBound.addingTimeInterval(-1)))"
        }
    }
}
