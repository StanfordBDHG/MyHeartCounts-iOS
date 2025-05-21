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
    
    @Environment(HeartHealthManager.self)
    private var manager
    
    @Environment(HealthKit.self)
    private var healthKit
    
    @State private var sampleTypeToAdd: MHCSampleType?
    
    var body: some View {
        NavigationStack {
            HealthDashboard(
                layout: manager.layout,
                goalProvider: { _ in nil },
                addSampleHandler: { sampleType in
                    sampleTypeToAdd = sampleType
                }
            )
            .navigationTitle("Heart Health")
            .toolbar {
                accountToolbarItem
            }
            .sheet(item: $sampleTypeToAdd) { sampleType in
                NavigationStack {
                    switch sampleType {
                    case .healthKit(.quantity(let sampleType)):
                        SaveQuantitySampleView(sampleType: sampleType)
                    default:
                        Text("Unhandled Sample Type: \(sampleType.displayTitle)")
                    }
                }
            }
        }
    }
}
