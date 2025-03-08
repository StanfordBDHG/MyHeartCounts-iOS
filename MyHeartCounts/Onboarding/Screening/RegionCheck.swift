//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import Foundation
import Spezi
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct RegionCheck: View {
    @Environment(\.locale)
    private var locale
    
    private let allowedRegions: Set<Locale.Region>
    private let regionsToChooseFrom: [Locale.Region]
    // lets hope we never run any arctic studies using this app...
    private let somewhereElseRegion: Locale.Region = .antarctica
    
    @State private var selection: Locale.Region?
    @State private var isAllowedToContinue = false
    
    var body: some View {
        ScreeningStep(title: "Region", canContinue: isAllowedToContinue) {
            Form {
                Section {
                    Text("Where do you currently live?")
                }
                Section {
                    Picker("", selection: $selection) {
                        ForEach(regionsToChooseFrom, id: \.identifier) { region in
                            Text(displayTitle(for: region)).tag(region)
                        }
                        Text("Somewhere else")
                            .tag(somewhereElseRegion)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    if let region = allowedRegions.first, allowedRegions.count == 1 {
                        Text("My Heart Counts is available to residents in \(displayTitle(for: region))")
                    } else { // count > 1
                        Text("My Heart Counts is available to residents in any of the following regions: \(allowedRegions.map(displayTitle(for:)).sorted().joined(separator: ", "))")
                    }
                }
            }
        }
        
        .onAppear {
            guard selection == nil else {
                return
            }
            if let region = locale.region {
                selection = allowedRegions.contains(region) ? region : somewhereElseRegion
            }
        }
        .onChange(of: selection) { _, newValue in
            if let newValue, allowedRegions.contains(newValue) {
                isAllowedToContinue = true
            } else {
                isAllowedToContinue = false
            }
        }
    }
    
    init(allowedRegions: Set<Locale.Region>) {
        precondition(!allowedRegions.isEmpty)
        self.allowedRegions = allowedRegions
        self.regionsToChooseFrom = [
            .unitedStates, .unitedKingdom
        ]
    }
    
    private func displayTitle(for region: Locale.Region) -> String {
        locale.localizedString(forRegionCode: region.identifier) ?? region.identifier
    }
}
