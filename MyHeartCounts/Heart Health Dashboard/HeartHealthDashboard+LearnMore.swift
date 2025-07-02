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

extension HeartHealthDashboard {
    struct LearnMore: View {
        var body: some View {
            Section {
                let text = String(localized: "HEART_HEALTH_DASHBOARD_LEARN_MORE_TEXT")
                MarkdownView(markdownDocument: .init(metadata: [:], blocks: [.markdown(id: nil, rawContents: text)]))
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: HealthDashboardConstants.gridComponentCornerRadius))
                    .padding([.horizontal, .bottom])
            } header: {
                HStack {
                    Text("Learn More")
                        .foregroundStyle(.secondary)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.leading)
                .padding(.leading)
            }
        }
    }
}
