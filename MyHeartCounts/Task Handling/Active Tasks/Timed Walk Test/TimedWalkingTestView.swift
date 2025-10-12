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


struct TimedWalkingTestView: View {
    typealias ResultHandler = @Sendable @MainActor (TimedWalkingTestResult?) async -> Void
    
    @Environment(\.openSettingsApp)
    private var openSettingsApp
    
    @Environment(\.openURL)
    private var openUrl
    
    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(WatchConnection.self)
    private var watchManager
    
    @Environment(TimedWalkingTest.self)
    private var timedWalkingTest
    
    private let test: TimedWalkingTestConfiguration
    private let resultHandler: ResultHandler
    
    @State private var viewState: ViewState = .idle
    @State private var showPermissionsErrorSection = false
    
    @State private var didCompleteAtLeastOneTest = false
    @State private var mostRecentResult: TimedWalkingTestResult?
    
    private var testIsRunning: Bool {
        timedWalkingTest.state.isActive
    }
    
    private var textName: LocalizedStringResource {
        let durationInMinutes = (test.duration.totalSeconds / 60).formatted(.number.precision(.fractionLength(0...1)))
        return switch test.kind {
        case .walking:
            LocalizedStringResource("\(durationInMinutes)-Minute Walk Test")
        case .running:
            if test == .twelveMinuteRunTest {
                LocalizedStringResource("12-Minute Run Test (Cooper Test)")
            } else {
                LocalizedStringResource("\(durationInMinutes)-Minute Run Test")
            }
        }
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
        .onDisappear {
            if !didCompleteAtLeastOneTest {
                // view is getting dismissed without having performed the action
                Task {
                    await resultHandler(nil)
                }
            }
        }
        .toolbar {
            if !testIsRunning {
                DismissButton()
            }
        }
        .alert(
            "Test Completed",
            isPresented: Binding<Bool> {
                self.mostRecentResult != nil
            } set: { newValue in
                // Note that we intentionally ignore `newValue == true` in here!
                if !newValue {
                    self.mostRecentResult = nil
                }
            },
            presenting: mostRecentResult
        ) { _ in
            Button(role: .cancel) {
                dismiss()
            } label: {
                Text("OK")
            }
            .keyboardShortcut(.defaultAction)
            Button("Repeat") {}
        } message: { result in
            let meters = Measurement<UnitLength>(value: result.distanceCovered, unit: .meters)
            Text("You covered \(meters, format: .measurement(width: .wide, usage: .road)), and took \(result.numberOfSteps) steps.")
        }
    }
    
    private var watchParticipatesInTest: Bool {
        // intentionally not checking whether the watch app is reachable, since it might not have been launched yet.
        watchManager.userHasWatch && watchManager.isWatchAppInstalled
    }
    
    @ViewBuilder private var sections: some View {
        PlainSection {
            CenterH {
                Image(systemSymbol: test.kind.symbol)
                    .font(.system(size: 87))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
            }
        }
        PlainSection {
            VStack(alignment: .leading) {
                Text(textName)
            }
            .font(.title.bold())
            .multilineTextAlignment(.center)
        }
        if case let .testActive(session) = timedWalkingTest.state {
            PlainSection {
                Spacer()
                CenterH {
                    VStack(alignment: .center, spacing: 16) {
                        CountdownView(start: session.inProgressResult.startDate, end: session.inProgressResult.endDate)
                        Text("Your \(textName) is in progress.")
                            .multilineTextAlignment(.center)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        if !testIsRunning {
            PlainSection {
                let kindText: LocalizedStringResource = switch test.kind {
                case .walking: "walk"
                case .running: "run"
                }
                switch test {
                case .sixMinuteWalkTest:
                    Text("TIMED_WALK_TEST_EXPLAINER_6_MIN_WALK")
                case .twelveMinuteRunTest:
                    Text("TIMED_WALK_TEST_EXPLAINER_12_MIN_RUN")
                default:
                    // ???
                    Text("TIMED_WALK_TEST_EXPLAINER_6_MIN_WALK")
                }
                if watchParticipatesInTest {
                    Text("For optimal results, please keep your Phone in your pocket, and \(kindText) until your Watch vibrates to indicate that the test has ended.")
                } else {
                    Text("For optimal results, please keep your Phone in your pocket, and \(kindText) until it vibrates to indicate that the test has ended.")
                }
                Text("TIMED_WALK_TEST_EXPLAINER_FOOTER")
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
                        await openSettingsApp()
                    }
                )
            }
            if watchManager.userHasWatch && !watchManager.isWatchAppInstalled {
                ErrorSection(
                    title: "Companion Watch App Not Installed",
                    explanation: "Installing My Heart Counts on your Apple Watch will allow us to greatly increase the quality of the recorded data.",
                    actionText: "Install on Apple Watch",
                    action: {
                        await openUrl("itms-watchs://")
                    }
                )
            }
        }
        if timedWalkingTest.state == .idle && timedWalkingTest.mostRecentResult == nil {
            Section {
                AsyncButton(state: $viewState) {
                    do {
                        let result = try await timedWalkingTest.start(test)
                        self.mostRecentResult = result
                        if !didCompleteAtLeastOneTest && result != nil {
                            didCompleteAtLeastOneTest = true
                        }
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
        }
    }
    
    
    init(_ test: TimedWalkingTestConfiguration, resultHandler: @escaping ResultHandler = { _ in }) {
        self.test = test
        self.resultHandler = resultHandler
    }
}


extension TimedWalkingTestView {
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


    private struct CountdownView: View {
        let start: Date
        let end: Date

        var body: some View {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(end.timeIntervalSince(context.date)))
                let minutes = remaining / 60
                let seconds = remaining % 60
                Text(String(format: "%d:%02d", minutes, seconds))
                    .font(.system(size: 70, design: .rounded).bold())
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeInOut(duration: 0.2), value: remaining)
            }
        }
    }
    
    
    private struct ErrorSection: View {
        let icon: SFSymbol
        let title: LocalizedStringResource
        let explanation: LocalizedStringResource
        let actionText: LocalizedStringResource
        let action: @MainActor @Sendable () async -> Void
        
        
        var body: some View {
            Section {
                HStack(alignment: .top) {
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
                AsyncButton {
                    await action()
                } label: {
                    Text(actionText)
                        .padding(.leading, 29)
                }
            }
        }
        
        
        init( // swiftlint:disable:next function_default_parameter_at_end
            icon: SFSymbol = .exclamationmarkTriangle,
            title: LocalizedStringResource,
            explanation: LocalizedStringResource,
            actionText: LocalizedStringResource,
            action: @Sendable @escaping () async -> Void
        ) {
            self.icon = icon
            self.title = title
            self.explanation = explanation
            self.actionText = actionText
            self.action = action
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
