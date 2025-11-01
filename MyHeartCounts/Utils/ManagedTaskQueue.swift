//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation

/// A Managed Task Queue
///
/// NOTE that there is obvious room for improvements here!
/// In fact, this implrmentation is pretty bad in some very significant ways:
/// - it doesn't start running any of the submitted tasks until the closure submitting them (the `body` param in ``withManagedTaskQueue(limit:_:)``) has returned
/// - it uses a fixed number of long-lived `Task`s, each of which acts as a runner processing submitted operations until they have all been completed
/// - we might instead use a more elegant system where we have an actor that has an array of waiters (continuations), and we use that to chain the tasks together?
final class ManagedTaskQueue: @unchecked Sendable {
    typealias Operation = @Sendable () async -> Void
    
    private let lock = RWLock()
    private var operations: [Operation] = []
    private var canSubmit = true
    
    fileprivate init() {}
    
    func submit(_ operation: @escaping Operation) {
        lock.withWriteLock {
            precondition(canSubmit, "Cannot submit task to already-closed TaskQueue!")
            operations.append(operation)
        }
    }
    
    fileprivate func stopTakingSubmissions() {
        lock.withWriteLock {
            canSubmit = false
        }
    }
    
    fileprivate func pop() -> Operation? {
        lock.withWriteLock {
            !operations.isEmpty ? operations.removeFirst() : nil
        }
    }
}


func withManagedTaskQueue(limit: Int, _ body: (_ taskQueue: ManagedTaskQueue) async -> Void) async {
    let taskQueue = ManagedTaskQueue()
    await body(taskQueue)
    taskQueue.stopTakingSubmissions()
    await withDiscardingTaskGroup { taskGroup in
        for _ in 0..<limit {
            taskGroup.addTask {
                while let operation = taskQueue.pop() {
                    await operation()
                }
            }
        }
    }
}
