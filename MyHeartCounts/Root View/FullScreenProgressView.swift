//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct FullScreenProgressView: View {
    private let title: LocalizedStringResource
    private let subtitle: LocalizedStringResource?
    
    var body: some View {
        ProgressView {
            VStack(alignment: .center) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.background)
    }
    
    init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
}
