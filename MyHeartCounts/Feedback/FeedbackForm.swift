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


struct FeedbackForm: View {
    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(FeedbackManager.self)
    private var feedbackManager
    
    @State private var text = ""
    @State private var viewState: ViewState = .idle
    @FocusState private var isEditing
    
    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .focused($isEditing)
                    .onAppear {
                        if text.isEmpty {
                            isEditing = true
                        }
                    }
            } footer: {
                Text("FEEDBACK_FORM_FOOTER_TEXT")
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(!text.isEmpty || viewState != .idle)
        .viewStateAlert(state: $viewState)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(viewState != .idle)
            }
            ToolbarItem(placement: .primaryAction) {
                AsyncButton("Send", state: $viewState) {
                    guard !text.isEmpty else {
                        return
                    }
                    try await feedbackManager.submit(message: text)
                    dismiss()
                }
                .bold()
                .disabled(text.isEmpty)
            }
        }
    }
}
