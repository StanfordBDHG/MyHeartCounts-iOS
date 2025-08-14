//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreMotion
import Foundation
import SFSafeSymbols
import Spezi
import SpeziFoundation
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct TimedWalkingTestView: View { // swiftlint:disable:this file_types_order
    typealias ResultHandler = @Sendable @MainActor (TimedWalkingTestResult?) async -> Void
    
    @Environment(\.openAppSettings)
    private var openAppSettings
    
    @Environment(\.openURL)
    private var openUrl
    
    @Environment(WatchConnection.self)
    private var watchManager
    
    @Environment(TimedWalkingTest.self)
    private var timedWalkingTest
    
    private let test: TimedWalkingTestConfiguration
    private let resultHandler: ResultHandler
    
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
        .task {
            switch CMMotionManager.authorizationStatus() {
            case .denied:
                showPermissionsErrorSection = true
            case .authorized, .notDetermined, .restricted:
                break
            @unknown default:
                break
            }
        }
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
        if !testIsRunning {
            if watchManager.userHasWatch && !watchManager.isWatchAppReachable {
                PlainSection {
                    Text("If you have an Apple Watch, please ensure that the My Heart Counts app is running")
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
            if let results = timedWalkingTest.mostRecentResult {
                Section("Results") {
                    LabeledContent("Date", value: results.startDate, format: .dateTime)
                    LabeledContent("#Steps", value: results.numberOfSteps, format: .number)
                    LabeledContent("Distance", value: results.distanceCovered, format: .number)
                }
            }
            if showPermissionsErrorSection {
                ErrorSection(
                    title: "Missing Required Motion Data Access Permission",
                    explanation: "The Timed Walking Test requires read access to Motion and Fitness Data.",
                    actionText: "Open Settings",
                    action: {
                        openAppSettings()
                    }
                )
            }
            if watchManager.userHasWatch && !watchManager.isWatchAppInstalled {
                ErrorSection(
                    title: "Companion Watch App Not Installed",
                    explanation: "Installing My Heart Counts on your Apple Watch will allow us to greatly increase the quality of the recorded data.",
                    actionText: "Install on Apple Watch",
                    action: {
                        openUrl("itms-watchs://")
                    }
                )
            }
        }
        switch timedWalkingTest.state {
        case .idle:
            Section {
                // Q: do we want to have an option to cancel the test?
                AsyncButton(state: $viewState) {
                    do {
                        let result = try await timedWalkingTest.start(test)
                        await resultHandler(result)
                    } catch TimedWalkingTest.TestError.unableToStart(.missingSensorPermissions) {
                        showPermissionsErrorSection = true
                    }
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
    }
    
    
    init(_ test: TimedWalkingTestConfiguration, resultHandler: @escaping ResultHandler = { _ in }) {
        self.test = test
        self.resultHandler = resultHandler
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
            .multilineTextAlignment(.leading)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
}


extension TimedWalkingTestView {
    private struct ErrorSection: View {
        let title: LocalizedStringResource
        let explanation: LocalizedStringResource
        let actionText: LocalizedStringResource
        let action: @MainActor () -> Void
        
        var body: some View {
            Section {
                HStack {
                    Image(systemSymbol: .exclamationmarkTriangle)
                        .accessibilityLabel("Warning Sign")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.headline)
                        Text(explanation)
                            .font(.subheadline)
                    }
                }
                Button {
                    action()
                } label: {
                    Text(actionText)
                        .padding(.leading, 29)
                }
            }
        }
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
