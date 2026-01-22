//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import Foundation


extension Date {
    /// Adds nanoseconds to a date.
    @inlinable
    public func addingNanoseconds(_ nanoseconds: Int64) -> Date {
        addingTimeInterval(TimeInterval(nanoseconds) / 1_000_000_000)
    }
}


extension Calendar {
    /// Returns a `Date` that is "noon" in the day the date falls into.
    @inlinable
    public func makeNoon(_ date: Date) -> Date {
        if let result = self.date(bySettingHour: 12, minute: 0, second: 0, of: date, direction: .forward), isDate(result, inSameDayAs: date) {
            return result
        } else if let result = self.date(bySettingHour: 12, minute: 0, second: 0, of: date, direction: .backward), isDate(result, inSameDayAs: date) {
            return result
        } else {
            preconditionFailure("Unable to determine noon for input \(date)")
        }
    }
}


extension Date.FormatStyle {
    /// Removes all time-related components from the format style
    @inlinable
    public func omittingTime() -> Self {
        self.hour(.omitted)
            .minute(.omitted)
            .second(.omitted)
            .secondFraction(.omitted)
    }
}
