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
            .navigationTitle(Self.tabTitle)
            .toolbar {
                accountToolbarItem
            }
        }
    }
}
