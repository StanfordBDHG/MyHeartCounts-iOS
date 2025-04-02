//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SwiftUI


struct DebugOptionsView: View, RootViewTab {
    static var tabTitle: LocalizedStringResource { "Debug Stuff" }
    static var tabSymbol: SFSymbol { .ladybug }
    
    @LocalPreference(.sendHealthKitUploadNotifications)
    private var sendHealthKitUploadNotifications
    
    var body: some View {
        NavigationStack {
            Form {
                Section("HealthKit Upload") {
                    Toggle("Send local notifications", isOn: $sendHealthKitUploadNotifications)
                }
            }
            .navigationTitle(String(localized: Self.tabTitle))
        }
    }
}
