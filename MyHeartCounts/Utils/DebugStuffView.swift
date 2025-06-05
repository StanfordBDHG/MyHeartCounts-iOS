//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI
import UIKit


struct DebugStuffView: View {
    @State private var isTimedWalkingTestSheetShown = false
    
    var body: some View {
        Form {
            Section {
                Button("Timed Walking Test") {
                    isTimedWalkingTestSheetShown = true
                }
            }
            Section {
                Button("Replace Root View Controller", role: .destructive) {
                    // The idea here is that replacing the root view controller should deallocate all our resources.
                    // We can then launch the memory graph debugger, and anything that's still in the left sidebar is leaked.
                    replaceRootVC()
                }
            }
        }
        .sheet(isPresented: $isTimedWalkingTestSheetShown) {
            NavigationStack {
                TimedWalkingTestView(.init(duration: .minutes(6), kind: .walking))
            }
        }
    }
    
    private func replaceRootVC() {
        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else {
            return
        }
        window.rootViewController = UIViewController()
    }
}
