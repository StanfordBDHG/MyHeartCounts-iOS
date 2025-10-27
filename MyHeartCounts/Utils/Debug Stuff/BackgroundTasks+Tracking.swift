//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import BackgroundTasks
import Foundation
import SwiftUI


extension MHCBackgroundTasks {
    struct Event: Hashable, Codable {
        enum Kind: String, Hashable, Codable {
            case start
            case stop
            case expiration
        }
        
        let date: Date
        let taskId: MHCBackgroundTasks.TaskIdentifier
        let kind: Kind
    }
    
    static func track(_ kind: Event.Kind, for taskId: TaskIdentifier) {
        LocalPreferencesStore.standard[.backgroundTaskEvents].append(.init(date: .now, taskId: taskId, kind: kind))
    }
}


extension LocalPreferenceKey {
    static var backgroundTaskEvents: LocalPreferenceKey<[MHCBackgroundTasks.Event]> {
        .make("backgroundTaskEvents", default: [])
    }
}


extension MHCBackgroundTasks {
    struct EventsView: View {
        @LocalPreference(.backgroundTaskEvents)
        private var events
        
        @State private var pendingRequests: [BGTaskRequest] = []
        
        var body: some View {
            Form {
                Section("Pending Tasks") {
                    ForEach(pendingRequests, id: \.self) { request in
                        VStack(alignment: .leading) {
                            Text(request.earliestBeginDate?.ISO8601Format() ?? "no begin date")
                            Text(request.identifier)
                                .monospaced()
                        }
                    }
                }
                Section("Event Log") {
                    ForEach(events.sorted(using: KeyPathComparator(\.date, order: .reverse)), id: \.self) { event in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(event.date, format: .iso8601)
                                Spacer()
                                Text(event.kind.rawValue)
                            }
                            Text(event.taskId.rawValue)
                        }
                    }
                }
            }
            .onAppear {
                reloadScheduledTasks()
            }
            .refreshable {
                reloadScheduledTasks()
            }
        }
        
        private func reloadScheduledTasks() {
            Task { @MainActor in
                pendingRequests = await BGTaskScheduler.shared.pendingTaskRequests()
            }
        }
    }
}
