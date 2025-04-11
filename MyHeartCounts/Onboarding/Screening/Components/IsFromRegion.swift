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
    
    @State private var isPresentingRegionPicker1 = false
    @State private var isPresentingRegionPicker2 = false
    
    var body: some View {
        @Bindable var data = data
        let allRegions = Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty }
            .sorted { $0.localizedName(in: locale) < $1.localizedName(in: locale) }
        let regionsList: [Locale.Region] = Array {
            if let currentRegion = locale.region {
                currentRegion
                allRegions.filter { $0 != currentRegion }
            } else {
                allRegions
            }
        }
        Button {
            isPresentingRegionPicker1 = true
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
        .contextMenu {
            Button("Use alternative region picker") {
                isPresentingRegionPicker2 = true
            }
        }
        .sheet(isPresented: $isPresentingRegionPicker1) {
            ListSelectionSheet("Select a Region", items: regionsList, selection: $data.region) { region in
                if let emoji = region.flagEmoji {
                    "\(emoji) \(region.localizedName(in: locale))"
                } else {
                    region.localizedName(in: locale)
                }
            }
        }
        .sheet(isPresented: $isPresentingRegionPicker2) {
            altRegionPicker
        }
    }
    
    
    @ViewBuilder private var altRegionPicker: some View {
        NavigationStack {
            let options: [RegionPickerEntry] = [
                .region(.unitedStates),
                .region(.unitedKingdom),
                .region(.europe),
                .region(.unknown),
                .somewhereElse
            ]
            FancyItemSelectionView(
                options,
                selection: Binding<RegionPickerEntry?> {
                    data.region.map { .region($0) } ?? .somewhereElse
                } set: {
                    data.region = $0?.region
                }
            ) { entry in
                HStack {
                    if let emoji = entry.region?.flagEmoji {
                        Text(emoji)
                    }
                    Text(entry.region?.localizedName(in: locale) ?? "Somewhere Else")
                        .font(.headline)
                    Spacer()
                }
            }
            .navigationTitle("Select Region")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                DismissButton()
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
