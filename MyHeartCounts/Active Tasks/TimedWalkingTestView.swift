//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreMotion
import Foundation
import MyHeartCountsShared
import SFSafeSymbols
import Spezi
import SpeziFoundation
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct TimedWalkingTestView: View { // swiftlint:disable:this file_types_order
    @Environment(\.openAppSettings)
    private var openAppSettings
    
    @Environment(\.openURL)
    private var openUrl
    
    @Environment(WatchConnection.self)
    private var watchManager
    
    @Environment(TimedWalkingTest.self)
    private var timedWalkingTest
    
    private let test: TimedWalkingTestConfiguration
    
    @State private var viewState: ViewState = .idle
    @State private var showPermissionsErrorSection = false
    
    private var testIsRunning: Bool {
        timedWalkingTest.state.isActive
    }
    
    var body: some View {
        Form {
            sections
        }
        .viewStateAlert(state: $viewState)
        .interactiveDismissDisabled(testIsRunning || viewState == .processing)
    }
    
    private var watchParticipatesInTest: Bool {
        // intentionally not checking whether the watch app is reachable, since it might not have been launched yet.
        watchManager.userHasWatch && watchManager.isWatchAppInstalled
    }
    
    @ViewBuilder private var sections: some View {
        PlainSection {
            CenterH {
                Text("Timed Walking Test")
                    .font(.title.bold())
            }
        }
        PlainSection {
            CenterH {
                Image(systemSymbol: test.kind.symbol)
                    .font(.system(size: 87))
                    .accessibilityLabel({ () -> String in
                        switch test.kind {
                        case .walking: "Symbol of person walking"
                        case .running: "Symbol of person running"
                        }
                    }())
            }
        }
        if watchManager.userHasWatch && !watchManager.isWatchAppInstalled {
            Section {
                HStack {
                    Image(systemSymbol: .exclamationmarkTriangle)
                        .accessibilityLabel("Warning Sign")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text("Companion Watch App Not Installed")
                            .font(.headline)
                        Text("Installing MyHeart Counts on your Apple Watch will allow us to greatly increase the quality of the recorded data.")
                            .font(.subheadline)
                    }
                }
                Button {
                    openUrl("itms-watchs://")
                } label: {
                    Text("Install on Apple Watch")
                        .padding(.leading, 29)
                }
            }
        }
        PlainSection {
            let durationInMinutes = (test.duration.totalSeconds / 60).formatted(.number.precision(.fractionLength(0...1)))
            let kindText = switch test.kind {
            case .walking: "walking"
            case .running: "running"
            }
            Text("As part of the \(test.displayTitle), we'll collect some mobility information from your iPhone and Apple Watch, such as Step Count, Distance, and Heart Rate, while you go on a short walk for \(durationInMinutes) minute\(test.duration == .minutes(1) ? "" : "s")")
            if watchParticipatesInTest {
                Text("For optimal results, please keep your Phone in your pocket, and \(kindText) until your Watch vibrates to indicate that the test has ended.")
            } else {
                Text("For optimal results, please keep your Phone in your pocket, and \(kindText) until it vibrates to indicate that the test has ended.")
            }
        }
        if watchManager.userHasWatch && !watchManager.isWatchAppReachable {
            PlainSection {
                Text("If you have an Apple Watch, please ensure that the MyHeart Counts app is running ")
                AsyncButton(state: $viewState) {
                    async let _ = withTimeout(of: .seconds(4)) {
                        print("timed out?")
                    }
                    try await watchManager.launchWatchApp()
                } label: {
                    Text("Launch Watch App")
                }
            }
        }
        switch timedWalkingTest.state {
        case .idle:
            Section {
                // Q: do we want to have an option to cancel the test?
                AsyncButton(state: $viewState) {
                    try await timedWalkingTest.start(test)
                } label: {
                    Text("Start Test")
                        .bold()
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.borderedProminent)
                .disabled(testIsRunning)
                .listRowInsets(.zero)
            }
        case .testActive(let session):
            Section("Current Test") {
                let timerInterval = session.inProgressResult.startDate...session.inProgressResult.endDate
                HStack {
                    Text("Time Elapsed")
                    Spacer()
                    Text(timerInterval: timerInterval, countsDown: false)
                }
                LabeledContent("Time Remaining") {
                    Text(timerInterval: timerInterval)
                }
            }
        }
        if let results = timedWalkingTest.mostRecentResult {
            Section("Results") {
                LabeledContent("Date", value: results.startDate, format: .dateTime)
                LabeledContent("#Steps", value: results.numberOfSteps, format: .number)
                LabeledContent("Distance", value: results.distanceCovered, format: .number)
            }
        }
    }
    
    
    init(_ test: TimedWalkingTestConfiguration) {
        self.test = test
    }
}


private struct CenterH<Content: View>: View {
    @ViewBuilder let content: @MainActor () -> Content
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            content()
            Spacer()
        }
    }
}


private struct PlainSection<Content: View>: View {
    private let content: Content
    
    var body: some View {
        content
            .multilineTextAlignment(.center)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
}


extension TimedWalkingTestConfiguration.Kind {
    var displayTitle: String {
        switch self {
        case .walking: "Walking"
        case .running: "Running"
        }
    }
    
    var symbol: SFSymbol {
        switch self {
        case .walking: .figureWalk
        case .running: .figureRun
        }
    }
}
