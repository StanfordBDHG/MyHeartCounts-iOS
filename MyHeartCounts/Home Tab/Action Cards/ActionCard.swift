//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziScheduler
import SpeziStudy


struct ActionCard: Identifiable {
    enum Action {
        case scheduledTaskAction(StudyManager.ScheduledTaskAction)
        case custom(() async -> Void)
    }
    
    enum Content: Identifiable {
        case event(Event)
        case custom(SimpleContent)
        
        var id: AnyHashable {
            switch self {
            case .event(let event):
                event.id
            case .custom(let content):
                content.id
            }
        }
    }
    
    
    struct SimpleContent: Identifiable, Hashable {
        let id: String
        let symbol: String?
        let title: String
        let message: String
    }
    
    let content: Content
    let action: Action
    
    var id: AnyHashable {
        content.id
    }
}
