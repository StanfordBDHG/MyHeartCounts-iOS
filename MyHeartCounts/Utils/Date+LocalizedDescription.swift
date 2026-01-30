//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//


import Foundation
import SpeziFoundation


extension Date {
    func localizedShortDescription(
        using cal: Calendar = .current,
        relativeTo now: Date = .now
    ) -> String {
        if cal.isDate(self, inSameDayAs: now) {
            return self.formatted(date: .omitted, time: .shortened)
        } else if cal.isDate(self, inSameDayAs: cal.startOfPrevDay(for: now)) {
            let timeDesc = self.formatted(date: .omitted, time: .shortened)
            let yesterday = String(localized: "Yesterday")
            return "\(yesterday), \(timeDesc)"
        } else {
            return self.formatted(date: .abbreviated, time: .shortened)
        }
    }
}
