//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import CoreMotion
import Foundation
import MyHeartCountsShared
import SFSafeSymbols
import Spezi
import SpeziFoundation
import SpeziViews
import SwiftUI


struct TimedWalkingTestView: View {
    private static let spellOutNumberFormatter: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .spellOut
        return fmt
    }()
    
    @Environment(\.openAppSettings)
    private var openAppSettings
    
    @Environment(\.openURL)
    private var openUrl
    
    @Environment(WatchConnection.self)
    private var watchManager
    
    @Environment(TimedWalkingTest.self)
    private var timedWalkingTest
    
//    private let test: TimedWalkingTest = .init(duration: .minutes(2), kind: .walking)
    
    @State private var duration: UInt = 1
    @State private var kind: TimedWalkingTestConfiguration.Kind = .walking
    
    @State private var viewState: ViewState = .idle
    @State private var showPermissionsErrorSection = false
    
    private var testIsRunning: Bool {
        timedWalkingTest.state.isActive
    }
    
    var body: some View {
        v3
            .viewStateAlert(state: $viewState)
            .interactiveDismissDisabled(testIsRunning || viewState == .processing)
    }
    
    private var watchParticipatesInTest: Bool {
        // intentionally not checking whether the watch app is reachable, since it might not have been launched yet.
        watchManager.userHasWatch && watchManager.isWatchAppInstalled
    }
    
    @ViewBuilder private var v1: some View {
        Form {
            if showPermissionsErrorSection {
                permissionsErrorSection
            }
            Section("Config") {
                Stepper("\(duration) minute\(duration == 1 ? "" : "s")", value: $duration, in: 0...20)
                Picker("Kind", selection: $kind) {
                    ForEach(TimedWalkingTestConfiguration.Kind.allCases, id: \.self) { kind in
                        Label(kind.displayTitle, systemSymbol: kind.symbol)
                    }
                }
                .pickerStyle(.menu)
            }
            .disabled(testIsRunning)
            Section {
                content
            }
            if let result = timedWalkingTest.tmpMostRecentResult {
                Section {
                    LabeledContent("Kind", value: result.test.kind.displayTitle)
                    LabeledContent("Duration", value: result.test.duration.formatted())
                    LabeledContent("Number of Steps", value: result.numberOfSteps, format: .number)
                    LabeledContent("Distance Covered", value: Measurement<UnitLength>(value: result.distanceCovered, unit: .meters), format: .measurement(width: .abbreviated))
                }
            }
            Section("Event Log") {
                ForEach(timedWalkingTest.dbg_eventLog.reversed()) { event in
                    VStack(alignment: .leading) {
                        Text(event.date, format: .iso8601)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(event.desc)
                    }
                }
            }
        }
        .navigationTitle("Timed Walking Test")
        .viewStateAlert(state: $viewState)
        .interactiveDismissDisabled(testIsRunning)
        .onAppear {
            showPermissionsErrorSection = [
                CMPedometer.authorizationStatus() == .denied,
                CMAltimeter.authorizationStatus() == .denied
            ].contains(true)
        }
    }
    
    @ViewBuilder private var content: some View {
        switch timedWalkingTest.state {
        case .idle:
            AsyncButton("Start", state: $viewState) {
                let test = TimedWalkingTestConfiguration(duration: .minutes(duration), kind: kind)
                try await timedWalkingTest.conduct(test)
            }
        case .testActive(let session):
            let timerInterval = session.preliminaryResults.startDate...session.preliminaryResults.endDate
            HStack {
                Text("Time Elapsed")
                Spacer()
                Text(timerInterval: timerInterval, countsDown: false)
            }
            LabeledContent("Time Remaining") {
                Text(timerInterval: timerInterval)
            }
            AsyncButton("Stop", state: $viewState) {
                try await timedWalkingTest.stop()
            }
        }
    }
    
    
    @ViewBuilder private var permissionsErrorSection: some View {
        Section {
            HStack {
                Image(systemSymbol: .exclamationmarkTriangle)
//                    .resizable()
//                    .frame(width: 27, height: 27)
                    .accessibilityLabel("Error Symbol")
                    .foregroundStyle(.red)
                VStack(alignment: .leading) {
                    Text("Missing Sensor Access Permissions")
                        .font(.headline)
                    Text("You need to grant MyHeart Counts access to Motion Data")
                        .font(.subheadline)
                }
            }
            Button {
                openAppSettings()
            } label: {
                Text("Open Settings")
                // TODO: align horizontally w/ text in row above!
            }
        }
    }
    
    
    @ViewBuilder private var v2: some View {
//        GeometryReader { geometry in
//            Text("Timed Walking Test")
//                .font(.title.bold())
////                .padding(.top, 40)
//                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.1)
//            Image(systemSymbol: kind.symbol)
//                .font(.system(size: 87))
//                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.39)
//            Spacer()
//            Group {
//                let durationSpelledOut = Self.spellOutNumberFormatter.string(from: NSNumber(value: duration)) ?? "\(duration)"
//                let kindText = switch kind {
//                case .walking: "Walk"
//                case .running: "Run"
//                }
//                
//                Text("The \(durationSpelledOut)-Minute \(kindText) Test collects some mobility-related information from your iPhone and Apple Watch, such as Step Count, Distance, and Heart Rate.")
//                
//                let isOngoing = conductor.state.isActive
//                
//                switch (kind, isOngoing) {
//                case (let kind, false):
//                    let kindText = switch kind {
//                    case .walking: "Walk"
//                    case .running: "Run"
//                    }
//                    Text("As part of the \(durationSpelledOut)-Minute \(kindText) Test, we'll collect some mobility information from your iPhone and Apple Watch, such as Step Count,  while you go on a short walk for \(duration) minute\(duration == 1 ? "" : "s")")
//                case (.running, false):
//                    Text("As part of the \(durationSpelledOut)-Minute Run Test, we'll collect some mobility information while you go on a short run for \(duration) minute\(duration == 1 ? "" : "s")")
//                case (.walking, true):
//                    Text("Please walk around for \(duration) minute\(duration == 1 ? "" : "s")")
//                case (.running, ):
//                    Text("Please go on a run for \(duration) minute\(duration == 1 ? "" : "s")")
//                }
//            }
//            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.61)
//        }
//        .multilineTextAlignment(.center)
    }
    
    @ViewBuilder private var v3: some View {
        Form {
            Section {
                CenterH {
                    Text("Timed Walking Test")
                        .font(.title.bold())
                }
            }
            .listRowBackground(Color.clear)
            CenterH {
                Image(systemSymbol: kind.symbol)
                    .font(.system(size: 87))
                //                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.39)
            }
            .listRowBackground(Color.clear)
            if watchManager.userHasWatch && !watchManager.isWatchAppInstalled {
                Section {
                    HStack {
                        Image(systemSymbol: .exclamationmarkTriangle)
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
            StyledSection {
                let durationSpelledOut = Self.spellOutNumberFormatter.string(from: NSNumber(value: duration))?.capitalized ?? "\(duration)"
                let kindText = switch kind {
                case .walking: "Walk"
                case .running: "Run"
                }
                Text("As part of the \(durationSpelledOut)-Minute \(kindText) Test, we'll collect some mobility information from your iPhone and Apple Watch, such as Step Count, Distance, and Heart Rate, while you go on a short walk for \(duration) minute\(duration == 1 ? "" : "s")")
                if watchParticipatesInTest {
                    Text("For optimal results, please keep your Phone in your pocket, and \(kindText.lowercased()) until your Watch vibrates to indicate that the test has ended.")
                } else {
                    Text("For optimal results, please keep your Phone in your pocket, and \(kindText.lowercased()) until it vibrates to indicate that the test has ended.")
                }
            }
            if watchManager.userHasWatch && !watchManager.isWatchAppReachable {
                StyledSection {
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
                    // TODO do we want to have an option to cancel the test?
                    AsyncButton(state: $viewState) {
//                        let test = TimedWalkingTest(duration: .minutes(duration), kind: kind)
                        let test = TimedWalkingTestConfiguration(duration: .seconds(20), kind: kind)
                        try await timedWalkingTest.conduct(test)
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
                    let timerInterval = session.preliminaryResults.startDate...session.preliminaryResults.endDate
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
            if let results = timedWalkingTest.tmpMostRecentResult {
                Section("Results") {
                    LabeledContent("Date", value: results.startDate, format: .dateTime)
                    LabeledContent("#Steps", value: results.numberOfSteps, format: .number)
                    LabeledContent("Distance", value: results.distanceCovered, format: .number)
                }
            }
        }
    }
}


struct CenterH<Content: View>: View {
    @ViewBuilder let content: @MainActor () -> Content
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            content()
            Spacer()
        }
    }
}


private struct StyledSection<Content: View>: View { // TODO rename PlainSection?
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


//struct ActionableErrorMessageFormSection: View {
//    let symbol: SFSymbol
//    let title: String // LocalizedStringResource
//    let subtitle: String // LocalizedStringResource
//    let buttonTitle: String // LocalizedStringResource
//    let action: @MainActor () -> Void
//}


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
