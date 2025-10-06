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
        .stethoscope
    }
    
    var body: some View {
        NavigationStack {
            HeartHealthDashboard()
                .navigationTitle(Self.tabTitle)
                .toolbar {
                    accountToolbarItem
                }
        }
    }
}


extension AnySampleType {
    /// The sample type's display name, for usage in My Heart Counts.
    ///
    /// - Important: Always use this property instead of `displayTitle`!
    var mhcDisplayTitle: String {
        if self == .bloodGlucose {
            String(localized: "Hemoglobin A1c (HbA1c)")
        } else {
            self.displayTitle
        }
    }
}
