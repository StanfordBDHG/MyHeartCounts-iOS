//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MyHeartCountsShared
import SpeziFoundation
import SpeziViews
import SwiftUI


struct IsFromRegion: ScreeningComponent {
    let title: LocalizedStringResource = "Region"
    // swiftlint:disable attributes
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(OnboardingDataCollection.self) private var data
    // swiftlint:enable attributes
    
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
                Text("What country do you currently live in?")
                    .fontWeight(.medium)
                    .foregroundStyle(colorScheme.textLabelForegroundStyle)
                Spacer()
                if let region = data.screening.region {
                    Text(region.localizedName(in: locale, includeEmoji: .none))
                        .foregroundStyle(colorScheme.textLabelForegroundStyle.secondary)
                }
                DisclosureIndicator()
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .sheet(isPresented: $isPresentingRegionPicker) {
            ListSelectionSheet("Select a Region", items: regionsList, selection: $data.screening.region) { region in
                region.localizedName(in: locale, includeEmoji: .front)
            }
        }
    }
    
    func evaluate(_ data: OnboardingDataCollection) -> Bool {
        guard let region = data.screening.region else {
            return false
        }
        return allowedRegions.contains(region)
    }
}
