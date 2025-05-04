//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import Foundation
import Spezi


@Observable
@MainActor
final class NewsManager: Module, EnvironmentAccessible {
    private(set) var articles: [Article] = []
    
    
    private var newsCollection: CollectionReference {
        Firestore.firestore().collection("news")
    }
    
    func configure() {
        Task {
            try await refresh()
        }
    }
    
    
    @discardableResult
    func refresh() async throws -> [Article] {
        let query = try await newsCollection.getDocuments()
        articles = query.documents
            .compactMap { try? $0.data(as: Article.self) }
            .sorted(using: KeyPathComparator(\.date, order: .reverse))
        return articles
    }
}
