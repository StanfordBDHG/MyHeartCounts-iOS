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
    func displayText(using cal: Calendar) -> String { // swiftlint:disable:this cyclomatic_complexity
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
        } else if lowerBound == cal.startOfDay(for: lowerBound),
                  upperBound == cal.startOfDay(for: upperBound),
                  upperBound == cal.startOfNextDay(for: .now) {
            let distance = cal.dateComponents([.day, .weekOfYear, .month, .year], from: lowerBound, to: upperBound)
            // SAFETY: we've explicitly requested these components.
            let years = distance.year! // swiftlint:disable:this force_unwrapping
            let months = distance.month! // swiftlint:disable:this force_unwrapping
            let weeks = distance.weekOfYear! // swiftlint:disable:this force_unwrapping
            let days = distance.day! // swiftlint:disable:this force_unwrapping
            if years > 0, months == 0, weeks == 0, days == 0 {
                return String(localized: "Past \(years) years")
            } else if months > 0, years == 0, weeks == 0, days == 0 {
                return String(localized: "Past \(months) months")
            } else if weeks > 0, years == 0, months == 0, days == 0 {
                // doing "Past N days" here instead of "Past N weeks", bc this is anchored to the end of the current day (checked above),
                // and this makes that clear (instead of the time range being the past N full weeks)
                return String(localized: "Past \(weeks * 7) days")
            } else if days > 0, years == 0, months == 0, weeks == 0 {
                return String(localized: "Past \(days) days")
            }
        }
        // fallback, if nothing above returned
        let fmt = { ($0 as Date).formatted(date: .numeric, time: .omitted) }
        return "\(fmt(self.lowerBound)) – \(fmt(self.upperBound.addingTimeInterval(-1)))"
    }
}
