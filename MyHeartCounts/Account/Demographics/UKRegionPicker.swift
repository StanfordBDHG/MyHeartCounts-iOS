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


struct UKRegionPicker: View {
    @Binding var selection: UKRegion?
    
    var body: some View {
        Form {
            Section("Region") {
                makeRow("England", counties: UKRegion.County.englishCounties, makeRegion: UKRegion.england)
                makeRow("Scotland", counties: UKRegion.County.scottishCounties, makeRegion: UKRegion.scotland)
                makeRow("Wales", counties: UKRegion.County.welshCounties, makeRegion: UKRegion.wales)
                makeRow("Northern Ireland", counties: UKRegion.County.northernIrishCounties, makeRegion: UKRegion.northernIreland)
            }
        }
        .navigationTitle("Select a Region")
    }
    
    @ViewBuilder
    private func makeRow(_ title: String, counties: [UKRegion.County], makeRegion: @escaping (UKRegion.County) -> UKRegion) -> some View {
        NavigationLink {
            Form {
                ForEach(counties) { county in
                    let region = makeRegion(county)
                    Button {
                        selection = region
                    } label: {
                        HStack {
                            Text(county.name)
                            Spacer()
                            if region == selection {
                                Image(systemSymbol: .checkmark)
                                    .fontWeight(.medium)
                                    .accessibilityLabel("Selection Checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .navigationTitle(title)
        } label: {
            HStack {
                Text(title)
                Spacer()
                if let county = selection?.county {
                    Text(county.name)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
