//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MarkdownUI
import SpeziViews
import SwiftUI


struct ECGInstructionsSheet: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    let text = String(localized: "ECG_INSTRUCTIONS_TEXT")
                    Markdown(text)
                        .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton()
                }
            }
        }
    }
}
