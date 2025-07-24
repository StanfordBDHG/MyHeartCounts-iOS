//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Dispatch
import Foundation


@globalActor
actor SensorKitActor {
    /// The shared actor instance.
    static let shared = SensorKitActor()
    
    /// The underlying dispatch queue that runs the actor Jobs.
    nonisolated let dispatchQueue: DispatchSerialQueue
    
    /// The underlying unowned serial executor.
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        dispatchQueue.asUnownedSerialExecutor()
    }
    
    nonisolated var isSync: Bool {
        DispatchQueue.getSpecific(key: DispatchQueueKey.key) == DispatchQueueKey.shared
    }
    
    private init() {
        let dispatchQueue = DispatchQueue(label: "edu.stanford.MHC.SensorKit", qos: .userInitiated)
        guard let serialQueue = dispatchQueue as? DispatchSerialQueue else {
            preconditionFailure("Dispatch queue \(dispatchQueue.label) was not initialized to be serial!")
        }
        serialQueue.setSpecific(key: DispatchQueueKey.key, value: DispatchQueueKey.shared)
        self.dispatchQueue = serialQueue
    }
}


extension SensorKitActor {
    private struct DispatchQueueKey: Sendable, Hashable {
        static let shared = Self()
        static let key = DispatchSpecificKey<Self>()
        private init() {}
    }
}
