//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziScheduler
import SpeziStudy


extension HomeTab {
    struct PromptedAction: Identifiable {
        typealias Handler = @Sendable @MainActor () async throws -> Void
        
        struct ID: Hashable, Codable, Sendable {
            private let value: String
            
            init(_ value: String) {
                self.value = value
            }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                self.value = try container.decode(String.self)
            }
            
            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(self.value)
            }
        }
        
        struct Content: Hashable {
            let symbol: SFSymbol
            let title: LocalizedStringResource
            let message: LocalizedStringResource
        }
        
        let id: ID
        let content: Content
        let handler: Handler
    }
}
