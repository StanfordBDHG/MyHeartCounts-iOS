//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

@testable import MyHeartCounts
import Testing


private actor StatsConnectionProbe {
    enum Event: Equatable {
        case started(Int)
        case cancelled(Int)
        case finished(Int)
    }

    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation
    private let holdsFirstTeardown: Bool
    private var teardownWaiter: CheckedContinuation<Void, Never>?
    private var teardownReleased = false
    private var activeCount = 0
    private(set) var startCount = 0
    private(set) var maximumActiveCount = 0

    init(holdsFirstTeardown: Bool = false) {
        self.holdsFirstTeardown = holdsFirstTeardown
        (events, continuation) = AsyncStream.makeStream()
    }

    func run() async {
        startCount += 1
        let identifier = startCount
        activeCount += 1
        maximumActiveCount = max(maximumActiveCount, activeCount)
        continuation.yield(.started(identifier))
        let (idle, idleContinuation) = AsyncStream.makeStream(of: Void.self)
        for await _ in idle {}
        idleContinuation.finish()
        #expect(Task.isCancelled)
        continuation.yield(.cancelled(identifier))
        if identifier == 1, holdsFirstTeardown, !teardownReleased {
            await withCheckedContinuation { teardownWaiter = $0 }
        }
        activeCount -= 1
        continuation.yield(.finished(identifier))
    }

    func releaseTeardown() {
        teardownReleased = true
        teardownWaiter?.resume()
        teardownWaiter = nil
    }
}


@Suite(.timeLimit(.minutes(1)))
struct HealthKitStatsConnectivityTests {
    @Test
    func offlineConnectionNeverStartsWork() async {
        let (connections, input) = AsyncStream.makeStream(of: Bool.self)
        let probe = StatsConnectionProbe()
        input.yield(false)
        input.yield(false)
        input.finish()

        await HealthKitStatsCalculator.runWhileConnected(to: connections) {
            await probe.run()
        }
        #expect(await probe.startCount == 0)
    }

    /// Reconnecting waits for cancellation cleanup, while repeated online notifications preserve the current run.
    @Test
    func reconnectWaitsForTeardownAndCancellationStopsWork() async {
        let (connections, input) = AsyncStream.makeStream(of: Bool.self)
        let probe = StatsConnectionProbe(holdsFirstTeardown: true)
        var events = probe.events.makeAsyncIterator()
        let execution = Task {
            await HealthKitStatsCalculator.runWhileConnected(to: connections) {
                await probe.run()
            }
        }
        defer {
            execution.cancel()
            input.finish()
            Task { await probe.releaseTeardown() }
        }
        input.yield(true)
        #expect(await events.next() == .started(1))
        input.yield(true)
        input.yield(true)
        input.yield(false)
        #expect(await events.next() == .cancelled(1))
        input.yield(true)
        #expect(await probe.startCount == 1)
        await probe.releaseTeardown()
        #expect(await events.next() == .finished(1))
        #expect(await events.next() == .started(2))
        #expect(await probe.maximumActiveCount == 1)

        execution.cancel()
        await execution.value
        #expect(await events.next() == .cancelled(2))
        #expect(await events.next() == .finished(2))
        input.yield(true)
        input.finish()
        #expect(await probe.startCount == 2)
    }

    @Test
    func finishingConnectionStreamStopsCurrentWork() async {
        let (connections, input) = AsyncStream.makeStream(of: Bool.self)
        let probe = StatsConnectionProbe()
        var events = probe.events.makeAsyncIterator()
        let execution = Task {
            await HealthKitStatsCalculator.runWhileConnected(to: connections) {
                await probe.run()
            }
        }
        defer {
            execution.cancel()
            input.finish()
        }
        input.yield(true)
        #expect(await events.next() == .started(1))
        input.finish()
        await execution.value
        #expect(await events.next() == .cancelled(1))
        #expect(await events.next() == .finished(1))
        #expect(await probe.startCount == 1)
    }
}
