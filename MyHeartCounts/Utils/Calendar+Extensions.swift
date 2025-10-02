//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


extension Calendar {
    func makeNoon(_ date: Date) -> Date {
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
    /// Updates the `DateFormat`'s calendar and time zone, based on the input.
    func calendar(_ calendar: Calendar) -> Self {
        var copy = self
        copy.calendar = calendar
        copy.timeZone = calendar.timeZone
        return copy
    }
    
    func omittingTime() -> Self {
        self.hour(.omitted)
            .minute(.omitted)
            .second(.omitted)
            .secondFraction(.omitted)
    }
}
