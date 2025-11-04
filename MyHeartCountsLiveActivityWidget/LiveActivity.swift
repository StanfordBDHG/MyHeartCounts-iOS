//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import MyHeartCountsShared
import ActivityKit
import WidgetKit
import SFSafeSymbols
import SpeziStudyDefinition
import SwiftUI


struct MyHeartCountsLiveActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimedWalkTestLiveActivityAttributes.self) { (context: ActivityViewContext<TimedWalkTestLiveActivityAttributes>) in
            let test: TimedWalkingTestConfiguration = try! JSONDecoder().decode(TimedWalkingTestConfiguration.self, from: context.attributes.encodedTest)
            let startDate: Date = context.attributes.startDate
            makeWidget(for: test, startDate: startDate)
//                .activityBackgroundTint(Color.cyan)
                .activitySystemActionForegroundColor(Color.black)
                .padding([.horizontal, .top, .bottom])
        } dynamicIsland: { context in
            let test: TimedWalkingTestConfiguration = try! JSONDecoder().decode(TimedWalkingTestConfiguration.self, from: context.attributes.encodedTest)
            let startDate: Date = context.attributes.startDate
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    makeWidget(for: test, startDate: startDate)
                }
            } compactLeading: {
                Image(systemSymbol: test.kind.symbol)
            } compactTrailing: {
                let endDate = startDate + test.duration.totalSeconds
                Text("00:00")
                    .hidden()
                    .overlay(alignment: .center) {
                        Text("\(endDate, style: .timer)")
                    }
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            } minimal: {
                Image(systemSymbol: test.kind.symbol)
            }
            .keylineTint(Color.red)
        }
    }
    
    
    @ViewBuilder
    private func makeWidget(for test: TimedWalkingTestConfiguration, startDate: Date) -> some View {
        let endDate = startDate + test.duration.totalSeconds
        VStack {
            HStack {
                Text("My Heart Counts")
                    .font(.headline)
                Spacer()
                Text("Six-Minute Walk Test")
                Image(systemSymbol: test.kind.symbol)
            }
            Text(verbatim: "00:00")
                .hidden()
                .overlay(alignment: .center) {
                    Text("\(endDate, style: .timer)")
                        .contentTransition(.numericText(countsDown: true))
                }
                .font(.system(size: 50, design: .rounded).bold())
                .monospacedDigit()
                .multilineTextAlignment(.center)
        }
    }
}


extension TimedWalkingTestConfiguration.Kind {
    var symbol: SFSymbol {
        switch self {
        case .walking: .figureWalk
        case .running: .figureRun
        }
    }
}
