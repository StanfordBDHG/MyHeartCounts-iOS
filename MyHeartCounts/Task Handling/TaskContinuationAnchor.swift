//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


private struct TaskContinuationAnchor: ViewModifier {
    @Environment(TimedWalkingTest.self)
    private var timedWalkingTest
    
    @PerformTask private var performTask
    
    /// A currently active timed walk test session for which this view is responsible.
    ///
    /// Typically, timed walk test sessions are
    @State private var activeTimedWalkTestSession: TimedWalkingTest.ActiveSession?
    
    func body(content: Content) -> some View {
        content
            .sheet(item: $activeTimedWalkTestSession) { session in
                let test = session.inProgressResult.test
                TimedWalkingTestSheet(test) { result in
                    if result != nil {
                        try? performTask.reportCompletion(of: .timedWalkTest(test))
                    }
                }
            }
            .onChange(of: timedWalkingTest.state, initial: true) { oldState, newState in
                switch newState {
                case .testActive(let session):
                    if session.isRecoveredTest {
                        activeTimedWalkTestSession = session
                    } else {
                        activeTimedWalkTestSession = nil
                    }
                case .idle:
                    activeTimedWalkTestSession = nil
                }
            }
    }
}


extension View {
    func taskContinuationAnchor() -> some View {
        self.modifier(TaskContinuationAnchor())
    }
}
