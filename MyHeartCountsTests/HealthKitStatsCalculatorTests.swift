//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
@testable import MyHeartCounts
import Synchronization
import Testing


private actor StatsWriterProbe: HealthKitStatsCalculator.StatsDocumentWriting {
    enum Failure: Error {
        case rejected
    }

    private(set) var storedEntries: [Int]
    private(set) var writes = 0
    private var failNextWrite: Bool
    private let cancelDuringWrite: Bool
    private let acknowledgesImmediately: Bool
    private var completions: [@Sendable ((any Error)?) -> Void] = []
    nonisolated let writeCounts: AsyncStream<Int>
    private let writeCountContinuation: AsyncStream<Int>.Continuation

    init(
        storedEntries: [Int] = [],
        failNextWrite: Bool = false,
        cancelDuringWrite: Bool = false,
        acknowledgesImmediately: Bool = true
    ) {
        self.storedEntries = storedEntries
        self.failNextWrite = failNextWrite
        self.cancelDuringWrite = cancelDuringWrite
        self.acknowledgesImmediately = acknowledgesImmediately
        (writeCounts, writeCountContinuation) = AsyncStream.makeStream()
    }

    func writeStatsDocument<Entry: Codable & Sendable>(
        _ entries: [Entry],
        to _: HealthKitStatsCalculator.StatsDocumentDestination
    ) async throws {
        if failNextWrite {
            failNextWrite = false
            throw Failure.rejected
        }
        storedEntries = try #require(entries as? [Int])
        writes += 1
        if cancelDuringWrite {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        let (result, continuation) = AsyncThrowingStream<Void, any Error>.makeStream()
        if acknowledgesImmediately {
            continuation.finish()
        } else {
            completions.append { continuation.finish(throwing: $0) }
        }
        writeCountContinuation.yield(writes)
        for try await _ in result { }
        try Task.checkCancellation()
    }

    func completeNextWrite(error: (any Error)? = nil) throws {
        try #require(!completions.isEmpty)
        completions.removeFirst()(error)
    }
}


@Suite
struct HealthKitStatsCalculatorTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")! // swiftlint:disable:this force_unwrapping
        return calendar
    }()
    
    /// Midnight at the start of the day, in the test calendar's time zone.
    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    /// A fresh run after suspension covers every missed month, including across New Year.
    @Test(arguments: [1, 3])
    func restartedCoverageIncludesMissedMonths(monthsElapsed: Int) throws {
        let initialDate = try date(2026, 12, 15)
        let resumedDate = try #require(calendar.date(byAdding: .month, value: monthsElapsed, to: initialDate))
        let months = HealthKitStatsCalculator.months(since: initialDate, now: resumedDate, calendar: calendar)
        let expected = (monthsElapsed...12).map { String(format: "2026-%02d", $0) }
            + (1...monthsElapsed).map { String(format: "2027-%02d", $0) }
        #expect(months.map(\.documentId) == expected)
        for (previous, next) in zip(months, months.dropFirst()) {
            #expect(previous.range.upperBound == next.range.lowerBound)
        }
    }
    
    /// All metrics cover the full chart window, including both partially displayed months, in the local calendar.
    @Test(arguments: ["GMT", "Europe/Berlin", "Asia/Kathmandu"])
    func coverageIncludesTheFullYear(timeZone: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZone))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 4)))
        let months = HealthKitStatsCalculator.months(
            since: now.addingTimeInterval(-86400),
            now: now,
            calendar: calendar
        )
        #expect(months.count == 13)
        #expect(months.first?.documentId == "2025-09")
        #expect(months.last?.documentId == "2026-09")
        #expect(months.first?.range.lowerBound == calendar.date(from: DateComponents(year: 2025, month: 9, day: 1)))
        #expect(months.last?.range.upperBound == calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        for (previous, next) in zip(months, months.dropFirst()) {
            #expect(previous.range.upperBound == next.range.lowerBound)
        }
    }
    
    /// On the last day, the chart starts at a month boundary and needs only twelve complete months.
    @Test(arguments: [
        (2026, 9, 30, "2025-10", "2026-09"),
        (2024, 2, 29, "2023-03", "2024-02"),
        (2025, 2, 28, "2024-03", "2025-02"),
        (2026, 12, 31, "2026-01", "2026-12")
    ])
    func coverageAtMonthEnd(year: Int, month: Int, day: Int, firstMonth: String, lastMonth: String) throws {
        let months = HealthKitStatsCalculator.months(
            since: try date(year, month, 1),
            now: try date(year, month, day),
            calendar: calendar
        )
        #expect(months.count == 12)
        #expect(months.first?.documentId == firstMonth)
        #expect(months.last?.documentId == lastMonth)
    }
    
    /// Earlier enrollment extends the window beyond the minimum chart history.
    @Test(arguments: [(2026, 21), (2036, 141)])
    func coverageIncludesEarlierEnrollment(year: Int, expectedCount: Int) throws {
        let months = HealthKitStatsCalculator.months(
            since: try date(2025, 1, 15),
            now: try date(year, 9, 4),
            calendar: calendar
        )
        #expect(months.count == expectedCount)
        #expect(months.first?.documentId == "2025-01")
        #expect(months.last?.documentId == "\(year)-09")
    }
    
    /// A month's range spans exactly that month, in the calendar's time zone.
    @Test
    func monthContainingADate() throws {
        let month = try #require(HealthKitStatsCalculator.month(containing: try date(2019, 4, 17), calendar: calendar))
        #expect(month.documentId == "2019-04")
        let expectedRange = try date(2019, 4, 1)..<date(2019, 5, 1)
        #expect(month.range == expectedRange)
    }
}


extension HealthKitStatsCalculatorTests {
    /// The same empty recomputation either clears the previous reading or preserves it, depending on deletion evidence.
    @Test(arguments: [false, true])
    func emptySnapshotsRequireDeletionEvidence(hasDeletions: Bool) async throws {
        let writer = StatsWriterProbe()
        let persistence = makePersistence(for: writer)
        let destination = try statsDestination()
        let anchor = Mutex(0)
        try await persistence.persistStatsUpdate(
            [73], for: destination, hasDeletions: false, commitAnchor: { anchor.withLock { $0 = 1 } }
        )
        try await persistence.persistStatsUpdate(
            [Int](), for: destination, hasDeletions: hasDeletions, commitAnchor: { anchor.withLock { $0 = 2 } }
        )
        #expect(await writer.storedEntries == (hasDeletions ? [] : [73]))
        #expect(await writer.writes == (hasDeletions ? 2 : 1))
        #expect(anchor.withLock { $0 } == 2)
    }

    /// A rejected deletion write must leave its anchor available for the next run to replay.
    @Test
    func failedDeletionWriteCanBeReplayed() async throws {
        let writer = StatsWriterProbe(storedEntries: [73], failNextWrite: true)
        let persistence = makePersistence(for: writer)
        let destination = try statsDestination()
        let anchor = Mutex(0)
        await #expect(throws: StatsWriterProbe.Failure.self) {
            try await persistence.persistStatsUpdate(
                [Int](), for: destination, hasDeletions: true, commitAnchor: { anchor.withLock { $0 = 1 } }
            )
        }
        #expect(await writer.storedEntries == [73])
        #expect(anchor.withLock { $0 } == 0)

        try await persistence.persistStatsUpdate(
            [Int](), for: destination, hasDeletions: true, commitAnchor: { anchor.withLock { $0 = 1 } }
        )
        #expect(await writer.storedEntries.isEmpty)
        #expect(await writer.writes == 1)
        #expect(anchor.withLock { $0 } == 1)
    }

    /// A producer cannot enqueue its next snapshot before the previous one is acknowledged.
    @Test(.timeLimit(.minutes(1)))
    func writesWaitForServerAcknowledgement() async throws {
        let writer = StatsWriterProbe(acknowledgesImmediately: false)
        let persistence = makePersistence(for: writer)
        let destination = try statsDestination()
        let anchor = Mutex(0)
        var writeCounts = writer.writeCounts.makeAsyncIterator()
        let task = Swift::Task {
            try await persistence.persistStatsUpdate(
                [73], for: destination, hasDeletions: false, commitAnchor: { anchor.withLock { $0 = 1 } }
            )
            try await persistence.persistStatsUpdate(
                [74], for: destination, hasDeletions: false, commitAnchor: { anchor.withLock { $0 = 2 } }
            )
        }
        defer { task.cancel() }
        #expect(await writeCounts.next() == 1)
        #expect(await writer.writes == 1)
        #expect(anchor.withLock { $0 } == 0)

        try await writer.completeNextWrite()
        #expect(await writeCounts.next() == 2)
        #expect(anchor.withLock { $0 } == 1)
        try await writer.completeNextWrite()
        try await task.value
        #expect(anchor.withLock { $0 } == 2)
    }

    /// A server rejection arriving after enqueue leaves the deletion replayable until a later write succeeds.
    @Test(.timeLimit(.minutes(1)))
    func delayedDeletionRejectionCanBeReplayed() async throws {
        let writer = StatsWriterProbe(storedEntries: [73], acknowledgesImmediately: false)
        let persistence = makePersistence(for: writer)
        let destination = try statsDestination()
        let anchor = Mutex(0)
        var writeCounts = writer.writeCounts.makeAsyncIterator()
        let first = Swift::Task { @Sendable in
            try await persistence.persistStatsUpdate(
                [Int](), for: destination, hasDeletions: true, commitAnchor: { anchor.withLock { $0 = 1 } }
            )
        }
        defer { first.cancel() }
        #expect(await writeCounts.next() == 1)
        #expect(anchor.withLock { $0 } == 0)
        try await writer.completeNextWrite(error: StatsWriterProbe.Failure.rejected)
        await #expect(throws: StatsWriterProbe.Failure.self) { try await first.value }
        #expect(anchor.withLock { $0 } == 0)

        let replay = Swift::Task { @Sendable in
            try await persistence.persistStatsUpdate(
                [Int](), for: destination, hasDeletions: true, commitAnchor: { anchor.withLock { $0 = 1 } }
            )
        }
        defer { replay.cancel() }
        #expect(await writeCounts.next() == 2)
        try await writer.completeNextWrite()
        try await replay.value
        #expect(await writer.writes == 2)
        #expect(anchor.withLock { $0 } == 1)
    }

    /// Cancellation before or during enqueue must not acknowledge the deletion.
    @Test(arguments: [false, true])
    func cancellationPreservesTheAnchor(cancelDuringWrite: Bool) async throws {
        let destination = try statsDestination()
        let task = Swift::Task {
            let writer = StatsWriterProbe(cancelDuringWrite: cancelDuringWrite)
            let persistence = makePersistence(for: writer)
            let didCommitAnchor = Mutex(false)
            if !cancelDuringWrite {
                withUnsafeCurrentTask { $0?.cancel() }
            }
            await #expect(throws: CancellationError.self) {
                try await persistence.persistStatsUpdate(
                    [Int](), for: destination, hasDeletions: true, commitAnchor: { didCommitAnchor.withLock { $0 = true } }
                )
            }
            return (await writer.writes > 0, didCommitAnchor.withLock { $0 })
        }
        let (didWrite, didCommitAnchor) = await task.value
        #expect(didWrite == cancelDuringWrite)
        #expect(!didCommitAnchor)
    }

    /// Cancelling a pending acknowledgement returns promptly and a late success cannot advance its anchor.
    @Test(.timeLimit(.minutes(1)))
    func cancellationBeforeAcknowledgementIgnoresLateCompletion() async throws {
        let writer = StatsWriterProbe(acknowledgesImmediately: false)
        let persistence = makePersistence(for: writer)
        let destination = try statsDestination()
        let anchor = Mutex(0)
        var writeCounts = writer.writeCounts.makeAsyncIterator()
        let task = Swift::Task {
            try await persistence.persistStatsUpdate(
                [Int](), for: destination, hasDeletions: true, commitAnchor: { anchor.withLock { $0 = 1 } }
            )
        }
        defer { task.cancel() }
        #expect(await writeCounts.next() == 1)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(anchor.withLock { $0 } == 0)
        try await writer.completeNextWrite()
        #expect(anchor.withLock { $0 } == 0)
    }

    private func makePersistence(for writer: StatsWriterProbe) -> HealthKitStatsCalculator.StatsPersistence {
        .init(writer: writer)
    }

    private func statsDestination() throws -> HealthKitStatsCalculator.StatsDocumentDestination {
        let month = try #require(HealthKitStatsCalculator.month(containing: date(2026, 9, 1), calendar: calendar))
        return .init(metricId: .weight, month: month, entriesKey: .samples)
    }
}
