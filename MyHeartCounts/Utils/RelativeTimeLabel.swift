//
//  RelativeTimeLabel.swift
//  MyHeartCounts
//
//  Created by Lukas Kollmer on 05.03.25.
//

import Foundation
import SwiftUI


// TODO put this into SpeziViews?!
public struct RelativeTimeLabel: View {
    private let date: Date
    
    @Environment(\.calendar) private var cal
    
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
