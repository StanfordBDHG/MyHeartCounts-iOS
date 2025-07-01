//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import MyHeartCountsShared
import SpeziViews
import SwiftUI
import WatchKit


struct ContentView: View {
    @Environment(WorkoutManager.self)
    private var workoutManager
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        switch workoutManager.state {
        case .idle:
            inactiveContent
        case .active:
            activeContent
        }
    }
    
    @ViewBuilder private var inactiveContent: some View {
        VStack {
            Text("My Heart Counts")
                .font(.system(size: 21, weight: .semibold))
            Color.clear
                .frame(height: 40)
            Text("Open the app on your iPhone to start a\nSix-Minute Walk Test")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder private var activeContent: some View {
        Form {
            Section {
                HStack {
                    Text("Test ongoing")
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 40)
                }
            }
            Section {
                Text("See your iPhone for more information.")
            }
        }
        .navigationTitle("My Heart Counts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
