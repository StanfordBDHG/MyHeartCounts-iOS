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
    func displayText( // swiftlint:disable:this cyclomatic_complexity function_body_length
        using locale: Locale,
        calendar cal: Calendar = .current,
        timeZone: TimeZone = .current,
        now: Date = .now
    ) -> String {
        func fmt(
            _ date: Date,
            date dateStyle: Date.FormatStyle.DateStyle,
            time timeStyle: Date.FormatStyle.TimeStyle
        ) -> String {
            date.formatted(Date.FormatStyle(date: dateStyle, time: timeStyle, locale: locale, calendar: cal, timeZone: timeZone))
        }
        if self == cal.rangeOfDay(for: now) {
            return String(localized: "Today", locale: locale)
        } else if self == cal.rangeOfDay(for: cal.startOfPrevDay(for: now)) {
            return String(localized: "Yesterday", locale: locale)
        } else if self == cal.rangeOfDay(for: self.lowerBound) {
            return fmt(lowerBound, date: .abbreviated, time: .omitted)
        } else if self.isEmpty { // startDate == endDate
            let date = self.lowerBound
            return if cal.isDate(date, inSameDayAs: now) && date <= now {
                fmt(date, date: .omitted, time: .shortened)
            } else {
                // is older than today
                fmt(date, date: .abbreviated, time: .shortened)
            }
        } else if cal.isDate(lowerBound, inSameDayAs: upperBound) || upperBound == cal.startOfNextDay(for: lowerBound) {
            // non-empty range but they're in the same day
            let startTime = fmt(lowerBound, date: .omitted, time: .shortened)
            let endTime = fmt(cal.isDate(lowerBound, inSameDayAs: upperBound) ? upperBound : upperBound - 60, date: .omitted, time: .shortened)
            return if cal.isDate(lowerBound, inSameDayAs: now) { // starts today
                "\(startTime) – \(endTime)"
            } else if cal.isDate(lowerBound, inSameDayAs: cal.startOfPrevDay(for: now)) {
                // is in yesterday
                "\(String(localized: "Yesterday", locale: locale)) \(startTime) – \(endTime)"
            } else {
                "\(fmt(lowerBound, date: .abbreviated, time: .omitted)) \(startTime) – \(endTime)"
            }
        } else if lowerBound == cal.startOfDay(for: lowerBound), upperBound == cal.startOfDay(for: upperBound) {
            if upperBound == cal.startOfNextDay(for: now) {
                // range ends today
                let distance = cal.dateComponents([.day, .weekOfYear, .month, .year], from: lowerBound, to: upperBound)
                // SAFETY: we've explicitly requested these components.
                let years = distance.year! // swiftlint:disable:this force_unwrapping
                let months = distance.month! // swiftlint:disable:this force_unwrapping
                let weeks = distance.weekOfYear! // swiftlint:disable:this force_unwrapping
                let days = distance.day! // swiftlint:disable:this force_unwrapping
                if years > 0, months == 0, weeks == 0, days == 0 {
                    return String(localized: "Last \(years) years", locale: locale)
                } else if months > 0, years == 0, weeks == 0, days == 0 {
                    return String(localized: "Last \(months) months", locale: locale)
                } else if weeks > 0, years == 0, months == 0, days == 0 {
                    // doing "Past N days" here instead of "Past N weeks", bc this is anchored to the end of the current day (checked above),
                    // and this makes that clear (instead of the time range being the past N full weeks)
                    return String(localized: "Last \(weeks * 7) days", locale: locale)
                } else if days > 0, years == 0, months == 0, weeks == 0 {
                    return String(localized: "Last \(days) days", locale: locale)
                }
            } else {
                return "\(fmt(lowerBound, date: .abbreviated, time: .omitted)) – \(fmt(upperBound - 60, date: .abbreviated, time: .omitted))"
            }
        }
        // fallback, if nothing above returned
        let start = fmt(lowerBound, date: .abbreviated, time: .shortened)
        let end = fmt(upperBound == cal.startOfDay(for: upperBound) ? upperBound - 60 : upperBound, date: .abbreviated, time: .shortened)
        return "\(start) – \(end)"
    }
}
