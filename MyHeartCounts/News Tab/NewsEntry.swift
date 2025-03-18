//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziStudy
import SwiftUI

struct NewsEntry: Hashable, Codable, Sendable {
    let date: Date
    let category: String
    let title: String
    let image: String?
    let lede: String
    let body: String
}

extension NewsEntry: Identifiable {
    struct ID: Hashable {
        private let date: Date
        private let title: String
        
        fileprivate init(_ entry: NewsEntry) {
            date = entry.date
            title = entry.title
        }
    }
    
    var id: ID { .init(self) }
}


extension ArticleSheet.Content {
    init(_ other: NewsEntry) {
        self.init(
            title: other.title,
            date: other.date,
            categories: [other.category],
            lede: other.lede,
            headerImage: other.image.map { Image($0) },
            body: other.body
        )
    }
}
