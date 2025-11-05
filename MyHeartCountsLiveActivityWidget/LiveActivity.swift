//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ActivityKit
import MyHeartCountsShared
import SFSafeSymbols
import SpeziFoundation
import SpeziStudyDefinition
import SwiftUI
import WidgetKit


struct MyHeartCountsLiveActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimedWalkTestLiveActivityAttributes.self) { (context: ActivityViewContext<TimedWalkTestLiveActivityAttributes>) in
            makeWidget(for: context)
                .activitySystemActionForegroundColor(Color.black)
                .padding([.horizontal, .top, .bottom])
        } dynamicIsland: { context in
            let test: TimedWalkingTestConfiguration = context.attributes.test
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    makeWidget(for: context)
                }
            } compactLeading: {
                Image(systemSymbol: test.kind.symbol)
                    .tint(.green)
            } compactTrailing: {
                switch context.state {
                case .ongoing(let startDate):
                    let endDate = startDate + test.duration.totalSeconds
                    Text("00:00")
                        .hidden()
                        .overlay(alignment: .center) {
                            Text("\(endDate, style: .timer)")
                        }
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                case .completed:
                    Image(systemSymbol: .checkmark)
                        .tint(.green)
                }
            } minimal: {
                Image(systemSymbol: test.kind.symbol)
                    .tint(.green)
            }
            .keylineTint(Color.red)
        }
    }
    
    
    @ViewBuilder
    private func makeWidget(for context: ActivityViewContext<TimedWalkTestLiveActivityAttributes>) -> some View {
        let test = context.attributes.test
        VStack {
            HStack {
                Text("My Heart Counts")
                    .font(.headline)
                Spacer()
                Text(test.displayTitle)
                Image(systemSymbol: test.kind.symbol)
            }
            switch context.state {
            case .ongoing(let startDate):
                let endDate = startDate + test.duration.totalSeconds
                Text(verbatim: "00:00")
                    .hidden()
                    .overlay(alignment: .center) {
                        Text("\(endDate, style: .timer)")
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .font(.system(size: 50, design: .rounded).bold())
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            case let .completed(numSteps, distance):
                let verb: String = switch test.kind {
                case .walking: "walked"
                case .running: "ran"
                }
                let duration = Measurement<UnitDuration>(value: test.duration.timeInterval, unit: .seconds)
                Text("You \(verb) \(numSteps) steps and covered \(distance, format: .measurement(width: .wide, usage: .road)) over the past \(duration, format: .measurement(width: .wide, usage: .general, numberFormatStyle: .number.precision(.fractionLength(0...1))))")
            }
        }
    }
}
