//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


// TODO: make this more advanced (some options) and maybe put it into SpeziViews?
public struct RelativeTimeLabel: View {
    private let date: Date
    
    @Environment(\.calendar)
    private var cal
    
    public var body: some View {
        TimelineView(.everyMinute) { _ in
            Text(text)
        }
    }
    
    private var text: String {
        let fmt = RelativeDateTimeFormatter()
        return fmt.localizedString(for: date, relativeTo: .now)
    }
    
    
    public init(date: Date) {
        self.date = date
    }
}
