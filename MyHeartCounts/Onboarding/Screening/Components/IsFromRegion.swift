//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct IsFromRegion: ScreeningComponent {
    let title: LocalizedStringResource = "Region"
    
    @Environment(\.locale)
    private var locale
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(ScreeningDataCollection.self)
    private var data
    
    let allowedRegion: Locale.Region
    
    @State private var isPresentingRegionPicker = false
    
    var body: some View {
        @Bindable var data = data
        let allRegions = Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty }
            .sorted { $0.localizedName(in: locale) < $1.localizedName(in: locale) }
        Button {
            isPresentingRegionPicker = true
        } label: {
            HStack {
                Text("Where are you currently living?")
                    .fontWeight(.medium)
                    .foregroundStyle(colorScheme.buttonLabelForegroundStyle)
                Spacer()
                if let region = data.region {
                    Text(region.localizedName(in: locale))
                        .foregroundStyle(colorScheme.buttonLabelForegroundStyle.secondary)
                }
                DisclosureIndicator()
            }
            .contentShape(Rectangle())
        }
        .sheet(isPresented: $isPresentingRegionPicker) {
            ListSelectionSheet("Select a Region", items: allRegions, selection: $data.region) { region in
                if let emoji = region.flagEmoji {
                    "\(emoji) \(region.localizedName(in: locale))"
                } else {
                    region.localizedName(in: locale)
                }
            }
        }
    }
    
    func evaluate(_ data: ScreeningDataCollection) -> Bool {
        data.region == allowedRegion
    }
}
