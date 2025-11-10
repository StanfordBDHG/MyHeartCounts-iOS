//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziFoundation
import SwiftUI


@Observable
final class Lifecycle: ServiceModule, EnvironmentAccessible, @unchecked Sendable {
    private let rwLock = RWLock()
    private(set) var scenePhase: ScenePhase = .inactive
    
    func run() async {
        await TimedWalkingTest.endLiveActivity()
        nonisolated(unsafe) var continuation: CheckedContinuation<Void, Never>?
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation = $0 }
        } onCancel: {
            Task {
                await TimedWalkingTest.endLiveActivity()
            }
            _ = continuation
        }
    }
    
    func _set<T>(_ keyPath: KeyPath<Lifecycle, T>, to value: T) { // swiftlint:disable:this identifier_name
        guard let keyPath = keyPath as? ReferenceWritableKeyPath<Lifecycle, T> else {
            return
        }
        rwLock.withWriteLock {
            self[keyPath: keyPath] = value
        }
    }
}
