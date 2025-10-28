//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import SpeziLLMLocal
import SpeziLLMLocalDownload
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct LLMLocalDownloadStep: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var path
    
    var body: some View {
        LLMLocalDownloadView(
            model: .llama3_2_1B_4bit,
            downloadDescription: "The Llama3.3 1B model will be downloaded to enable on-device AI features."
        ) {
            path.nextStep()
        }
    }
}


#Preview {
    ManagedNavigationStack {
        LLMLocalDownloadStep()
    }
}
