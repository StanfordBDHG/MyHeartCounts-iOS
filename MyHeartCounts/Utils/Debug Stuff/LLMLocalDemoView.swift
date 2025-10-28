//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziLLM
import SpeziLLMLocal
import SpeziViews
import SwiftUI


struct LLMLocalDemoView: View {
    @Environment(LLMRunner.self) var runner
    @State var responseText = ""
    @State var viewState: ViewState = .idle
    
    var body: some View {
        Text(responseText)
            .viewStateAlert(state: $viewState)
            .task {
                viewState = .processing

                // Instantiate the `LLMLocalSchema` to an `LLMLocalSession` via the `LLMRunner`.
                let llmSession: LLMLocalSession = runner(
                    with: LLMLocalSchema(
                        model: .llama3_2_1B_4bit,
                    )
                )

                // Add in the prompt
                let context =
                [
                    [
                        "role": "user",
                        "content": "Create a motivational excercise message."
                    ]
                ]
                llmSession.customContext = context

                do {
                    viewState = .processing
                    
                    for try await token in try await llmSession.generate() {
                        responseText.append(token)
                    }
                    
                    viewState = .idle
                } catch {
                    print("LLM Generation Error: \(error)")
                    viewState = .error(error)
                }
            }
    }
}