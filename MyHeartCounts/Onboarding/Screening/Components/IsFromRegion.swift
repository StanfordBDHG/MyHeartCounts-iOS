//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziViews
import SwiftUI


struct IsFromRegion: ScreeningComponent {
    let title: LocalizedStringResource = "Region"
    
    @Environment(\.locale)
    private var locale
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(ScreeningDataCollection.self)
    private var data
    
    let allowedRegions: Set<Locale.Region>
    
    @State private var isPresentingRegionPicker = false
    
    var body: some View {
        @Bindable var data = data
        let allRegions = Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty }
            .sorted { $0.localizedName(in: locale, includeEmoji: .none) < $1.localizedName(in: locale, includeEmoji: .none) }
        let regionsList: [Locale.Region] = Array {
            if let currentRegion = locale.region {
                currentRegion
                allRegions.filter { $0 != currentRegion }
            } else {
                allRegions
            }
        }
        Button {
            isPresentingRegionPicker = true
        } label: {
            HStack {
                Text("Where are you currently living?")
                    .fontWeight(.medium)
                    .foregroundStyle(colorScheme.buttonLabelForegroundStyle)
                Spacer()
                if let region = data.region {
                    Text(region.localizedName(in: locale, includeEmoji: .none))
                        .foregroundStyle(colorScheme.buttonLabelForegroundStyle.secondary)
                }
                DisclosureIndicator()
            }
            .contentShape(Rectangle())
        }
        .sheet(isPresented: $isPresentingRegionPicker) {
            ListSelectionSheet("Select a Region", items: regionsList, selection: $data.region) { region in
                region.localizedName(in: locale, includeEmoji: .front)
            }
        }
    }
    
    func evaluate(_ data: ScreeningDataCollection) -> Bool {
        guard let region = data.region else {
            return false
        }
        return allowedRegions.contains(region)
    }
}
