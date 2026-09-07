//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Network


extension HealthKitStatsCalculator {
    /// Cancel the queries on disconnection and finish teardown before starting them again.
    /// The injected stream also lets tests exercise connection changes without changing the device's network.
    @concurrent
    static func runWhileConnected(
        to connections: AsyncStream<Bool>,
        operation: @escaping @Sendable () async -> Void
    ) async {
        var iterator = connections.makeAsyncIterator()
        while let connected = await iterator.next() {
            guard !Task.isCancelled else {
                return
            }
            guard connected else {
                continue
            }
            await withDiscardingTaskGroup { group in
                group.addTask {
                    guard !Task.isCancelled else {
                        return
                    }
                    await operation()
                }
                while await iterator.next() == true {
                    // A change between usable paths (e.g. Wi-Fi to cellular) needs no restart.
                }
                group.cancelAll()
            }
        }
    }

    /// The monitor belongs to the requested run, so reconnecting cannot undo an explicit stop.
    func runWhenConnected(id: UUID) async {
        let monitor = NWPathMonitor()
        let (connections, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        monitor.pathUpdateHandler = { path in
            continuation.yield(path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "edu.stanford.MyHeartCounts.statsConnectivity"))
        defer {
            monitor.cancel()
            continuation.finish()
        }
        await Self.runWhileConnected(to: connections) {
            await self.runQueries(id: id)
        }
    }
}
