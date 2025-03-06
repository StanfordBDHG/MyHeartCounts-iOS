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
    private struct RegionWithDisplayTitle {
        let region: Locale.Region
        let displayTitle: LocalizedStringResource
    }
    
    @Environment(\.locale) private var locale
    @Environment(OnboardingNavigationPath.self) private var path
    
    private let allowedRegions: Set<Locale.Region>
    private let regionsToChooseFrom: [RegionWithDisplayTitle]
    // lets hope we never run any arctic studies using this app...
    private let somewhereElseRegion: Locale.Region = .antarctica
    
    @State private var selection: Locale.Region?
    @State private var isAllowedToContinue = false
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(
                title: "Screening: Region",
                subtitle: "Before we can continue,\nwe need to learn a little about you"
            )
        } contentView: {
            Form {
                Section {
                    Text("Where do you currently live?")
                }
                Section {
                    Picker("", selection: $selection) {
                        ForEach(regionsToChooseFrom, id: \.region) { (entry: RegionWithDisplayTitle) in
                            Text(entry.displayTitle)
                                .tag(entry.region)
                        }
                        Text("Somewhere else")
                            .tag(somewhereElseRegion)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    if allowedRegions.count == 1 {
                        Text("My Heart Counts is available to residents in \(allowedRegions.first!.identifier)")
                    } else { // count > 1
                        Text("My Heart Counts is available to residents in any of the following regions: \(allowedRegions.map(\.identifier).sorted().joined(separator: ", "))")
                    }
                }
            }
        } actionView: {
            OnboardingActionsView("Continue") {
                path.nextStep()
            }
            .disabled(!isAllowedToContinue)
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
            .init(region: .unitedStates, displayTitle: "United States"),
            .init(region: .unitedKingdom, displayTitle: "United Kingdom")
        ]
    }
}
