//
//  PushDeliveryConfirmationQueueLogTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

@Suite("Push delivery confirmation queue: logs")
struct PushDeliveryConfirmationQueueLogTests {
    private let folder: QueueTestFolder
    private let clock = QueueTestClock(now: Date(timeIntervalSince1970: 1_800_000_000))
    private let sender = QueueTestSender()
    private let log = QueueTestLog()
    private let base: Int64 = 1_800_000_000_000

    init() throws {
        folder = try QueueTestFolder()
    }

    private func makeQueue(inbox: PushDeliveryConfirmationInbox? = nil) -> PushDeliveryConfirmationQueue {
        let log = log
        let clock = clock
        return PushDeliveryConfirmationQueue(
            inbox: inbox ?? folder.inbox,
            sender: sender,
            schedule: PushDeliveryConfirmationSchedule(random: { _ in 1 }),
            now: { clock.now },
            sleep: { await clock.sleep($0) },
            log: { log.append($0) }
        )
    }

    @Test("a pass with three records logs the start and one delete per record")
    func passStartedAndDeletes() async throws {
        try folder.write("a", receivedAt: base - 3000)
        try folder.write("b", receivedAt: base - 2000)
        try folder.write("c", receivedAt: base - 1000)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(log.lines == [
            "[Confirmations] Pass started, records: 3",
            "[Confirmations] HTTP 200 → delete",
            "[Confirmations] HTTP 200 → delete",
            "[Confirmations] HTTP 200 → delete"
        ])
    }

    @Test("404 is logged as delete")
    func rejectedIsDelete() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(404)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(log.lines.contains("[Confirmations] HTTP 404 → delete"))
    }

    @Test("500 is logged with the pause and the second 500 with the doubled pause")
    func serverErrorKeepsWithRetry() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(500, 500)
        let queue = makeQueue()

        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        await queue.passAtNextAttempt(clock: clock)
        await clock.waitForSleeps(2)

        #expect(log.lines.contains("[Confirmations] HTTP 500 → keep, retry in 10 s"))
        #expect(log.lines.contains("[Confirmations] HTTP 500 → keep, retry in 20 s"))
    }

    @Test("429 is logged with the first throttle pause")
    func throttledKeepsWithRetry() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(429)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(log.lines.contains("[Confirmations] HTTP 429 → keep, retry in 200 s"))
    }

    @Test("no response is logged with the first failure pause")
    func noResponseKeepsWithRetry() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(nil)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(log.lines.contains("[Confirmations] No response → keep, retry in 10 s"))
    }

    @Test("wake() during a pause logs the seconds left, rounded up")
    func waitingLogsRemainder() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(429)
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        clock.advance(by: 56.7)

        await queue.wakeAndWait()

        #expect(log.lines.contains("[Confirmations] Waiting, 144 s left"))
    }

    @Test("wake() with exactly 143 s left logs 143")
    func waitingLogsWholeSeconds() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(429)
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        clock.advance(by: 57)

        await queue.wakeAndWait()

        #expect(log.lines.contains("[Confirmations] Waiting, 143 s left"))
    }

    @Test("a newer last-success during a pause logs the reset")
    func pauseResetByExtensionSuccess() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(500, 200)
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        clock.advance(by: 1)
        try folder.writeLastSuccess(queueTestMilliseconds(clock.now))

        await queue.wakeAndWait()

        #expect(log.lines.contains("[Confirmations] Pause reset by extension success"))
    }

    @Test("a newer last-success without a pause logs no reset")
    func noResetWithoutPause() async throws {
        try folder.write("a", receivedAt: base - 1000)
        try folder.writeLastSuccess(base + 1000)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(!log.lines.contains("[Confirmations] Pause reset by extension success"))
    }

    @Test("429 left by the extension after the queue started is logged with the rounded-up remainder")
    func extensionThrottleLogged() async throws {
        let queue = makeQueue()
        clock.advance(by: 5)
        let throttledAt = queueTestMilliseconds(clock.now)
        try folder.write("a", receivedAt: base - 1000, lastStatusCode: 429, lastAttemptAt: throttledAt)
        clock.advance(by: 0.3)

        await queue.enableAndWait()

        #expect(log.lines.contains("[Confirmations] Extension got 429, retry in 200 s"))
    }

    @Test("an extension 429 older than its pause logs 0 s")
    func extensionThrottleInThePastLogsZero() async throws {
        let queue = makeQueue()
        clock.advance(by: 300)
        try folder.write("a", receivedAt: base - 1000, lastStatusCode: 429, lastAttemptAt: base + 1000)

        await queue.enableAndWait()

        #expect(log.lines.contains("[Confirmations] Extension got 429, retry in 0 s"))
    }

    @Test("an extension 429 during a longer failure wait logs the remainder of that wait")
    func extensionThrottleDuringLongerWait() async throws {
        sender.enqueue(500, 500, 500, 500, 500, 500)
        try folder.write("a", receivedAt: base - 1000)
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        for sleeps in 2...6 {
            await queue.passAtNextAttempt(clock: clock)
            await clock.waitForSleeps(sleeps)
        }
        clock.advance(by: 1)
        try folder.write("b", receivedAt: base - 500, lastStatusCode: 429, lastAttemptAt: queueTestMilliseconds(clock.now))

        await queue.wakeAndWait()

        #expect(log.lines.contains("[Confirmations] Extension got 429, retry in 319 s"))
    }

    @Test("dropped records are logged once per reason")
    func droppedLogged() async throws {
        let old = base - 200 * 24 * 3600 * 1000
        try folder.write("old1", receivedAt: old)
        try folder.write("old2", receivedAt: old - 1000)
        let broken = folder.directory.appendingPathComponent("broken").appendingPathExtension(PushDeliveryConfirmationRecord.releasedExtension)
        try Data("not json".utf8).write(to: broken)
        try folder.write("a", receivedAt: base - 3000)
        try folder.write("b", receivedAt: base - 2000)
        try folder.write("c", receivedAt: base - 1000)
        let queue = makeQueue(inbox: PushDeliveryConfirmationInbox(directory: folder.directory, maxRecords: 1))

        await queue.enableAndWait()

        #expect(log.lines.contains("[Confirmations] Dropped: older than 6 months, records: 2"))
        #expect(log.lines.contains("[Confirmations] Dropped: unreadable, records: 1"))
        #expect(log.lines.contains("[Confirmations] Dropped: over limit, records: 2"))
        #expect(log.lines.contains("[Confirmations] Pass started, records: 1"))
    }

    @Test("an empty folder logs nothing")
    func emptyFolderLogsNothing() async {
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(log.lines.isEmpty)
    }

    @Test("no line contains the confirmation url")
    func noUrlInLines() async throws {
        try folder.write("a", receivedAt: base - 3000)
        try folder.write("b", receivedAt: base - 2000)
        sender.enqueue(500, 404, 200)
        let queue = makeQueue()

        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        await queue.passAtNextAttempt(clock: clock)

        #expect(!log.lines.isEmpty)
        #expect(log.lines.allSatisfy { !$0.contains("example.com") && !$0.contains("confirm?id") })
    }
}
