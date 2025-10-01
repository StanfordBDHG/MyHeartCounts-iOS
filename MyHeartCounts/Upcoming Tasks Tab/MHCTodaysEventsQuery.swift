//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation
import SpeziScheduler
import SpeziStudy
import SwiftUI


/// Fetches all events we want to prompt the user to complete today.
@MainActor
@propertyWrapper
struct MHCTodaysEventsQuery: DynamicProperty {
    /// The query's primary time range.
    ///
    /// Note that this is **not** the full time range being queried for, but rather the time range for which we want all events.
    private let primaryTimeRange: Range<Date>
    @EventQuery private var impl: [Event]
    @Environment(StudyManager.self) private var studyManager // swiftlint:disable:this attributes
    
    var wrappedValue: [Event] {
        impl.filter { event in
            if primaryTimeRange.contains(event.occurrence.start) {
                // if the event is in the primary time range, it always gets included
                return true
            } else if event.occurrence.schedule.recurrence == nil {
                // if the schedule is a one-off thing, we also always include it.
                // this is intended to catch initial one-off study components that haven't been completed.
                return true
            } else {
                return false
            }
        }
    }
    
    init(_ timeRange: Range<Date>, dateOfEnrollment: Date) {
        self.primaryTimeRange = timeRange
        _impl = .init(in: min(timeRange.lowerBound, Calendar.current.startOfDay(for: dateOfEnrollment))..<timeRange.upperBound)
    }
}
