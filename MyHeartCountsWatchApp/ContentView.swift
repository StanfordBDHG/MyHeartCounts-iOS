//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziViews
import SwiftUI


struct ContentView: View {
    @Environment(WorkoutManager.self)
    private var workoutManager
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        switch workoutManager.state {
        case .idle:
            inactiveContent
        case .active(let startDate):
            activeContent(startDate: startDate)
        }
    }
    
    @ViewBuilder private var inactiveContent: some View {
        VStack {
            Text("MyHeart Counts")
                .font(.system(size: 21, weight: .semibold))
            Color.clear
                .frame(height: 40)
            Text("Open the app on your iPhone to start a\nSix-Minute Walk Test")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private func activeContent(startDate: Date) -> some View {
        Form {
            Section {
                HStack {
                    Text("Test ongoing")
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            Section {
                Text("See your iPhone for more information.")
            }
        }
        .navigationTitle("MyHeart Counts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
