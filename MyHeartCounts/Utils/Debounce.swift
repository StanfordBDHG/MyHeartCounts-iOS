//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all - implicitly called

import Foundation
import SwiftUI


@MainActor
@propertyWrapper
struct Debounce: DynamicProperty {
    private struct DefaultIdentifier: Hashable {}
    
    private let delay: Duration
    @State private var tasks: [AnyHashable: Task<Void, any Error>] = [:]
    
    var wrappedValue: Self {
        self
    }
    
    init(_ delay: Duration) {
        self.delay = delay
    }
    
    func callAsFunction(_ action: @escaping @MainActor () async throws -> Void) {
        callAsFunction(id: DefaultIdentifier(), action: action)
    }
    
    
    /// Schedules an explicitly-identified debounce
    func callAsFunction(id: some Hashable, action: @escaping @MainActor () async throws -> Void) {
        let id = AnyHashable(id)
        var task: Task<Void, any Error>? {
            get { tasks[id] }
            set { tasks[id] = newValue }
        }
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }
            try await action()
            task = nil
        }
    }
    
    /// Cancels the explicitly-identified debounce scheduled for the specified `id`.
    func cancel(id: some Hashable) {
        let id = AnyHashable(id)
        tasks.removeValue(forKey: id)?.cancel()
    }
}
