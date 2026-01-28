//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import Foundation
import SpeziAccount
import SpeziViews
import SwiftUI


struct DebugRemoteNotificationStuff: View {
    @Environment(Account.self) private var account: Account?
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        Form {
            AsyncButton("Trigger remote Notification" as String, state: $viewState) {
                try await triggerRemoteNotification()
            }
            .disabled(account == nil)
        }
        .viewStateAlert(state: $viewState)
    }
    
    private func triggerRemoteNotification() async throws {
        struct BacklogItem: Codable {
            let title: String
            let body: String
            let id: String
            let timestamp: Date
            let isLLMGenerated: Bool
            let generatedAt: Date
        }
        guard let userId = account?.details?.accountId else {
            return
        }
        let store = FirebaseFirestore.Firestore.firestore()
        let collection = store.collection("users/\(userId)/notificationBacklog")
        let item = BacklogItem(
            title: "NEW TEST NOTI",
            body: "NEW TEST BODY",
            id: "NEW TEST ID",
            timestamp: Date().addingTimeInterval(-10),
            isLLMGenerated: false,
            generatedAt: Date()
        )
        let doc = collection.document("TESTIDTESTIDTESTID")
        try await doc.setData(from: item)
    }
}
