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


struct ActionCard: Identifiable {
    enum Action {
        case custom(() async -> Void)
    }
    
    enum Content: Identifiable {
        case custom(SimpleContent)
        
        var id: AnyHashable {
            switch self {
            case .custom(let content):
                content.id
            }
        }
    }
    
    struct SimpleContent: Identifiable, Hashable {
        let id: String
        let symbol: SFSymbol?
        let title: LocalizedStringResource
        let message: LocalizedStringResource
    }
    
    let content: Content
    let action: Action
    
    var id: AnyHashable {
        content.id
    }
    
    init(content: Content, action: Action) {
        self.content = content
        self.action = action
    }
    
    init(content: SimpleContent, action: @escaping @Sendable () async -> Void) {
        self.init(content: .custom(content), action: .custom(action))
    }
}
