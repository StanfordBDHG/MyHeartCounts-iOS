//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziViews
import SwiftUI


struct TestView: View {
    var body: some View {
        TestView2()
    }
}


struct TestView2: View {
    var body: some View {
        Text("X")
            .contextMenu {
                Button("CM") {}
            }
    }
}


struct HeartHealthDashboardTab: RootViewTab {
    static var tabTitle: LocalizedStringResource {
        "Heart Health"
    }
    static var tabSymbol: SFSymbol {
        .heartTextSquare
    }
    
    var body: some View {
        NavigationStack {
            Form {
                HeartHealthDashboard()
            }
            .toolbar {
                accountToolbarItem
            }
        }
    }
}
