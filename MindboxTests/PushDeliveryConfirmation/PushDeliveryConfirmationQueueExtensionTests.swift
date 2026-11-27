//
//  PushDeliveryConfirmationQueueExtensionTests.swift
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

@Suite("Push delivery confirmation queue: what the extension left")
struct PushDeliveryConfirmationQueueExtensionTests {
    private let folder: QueueTestFolder
    private let clock = QueueTestClock(now: Date(timeIntervalSince1970: 1_800_000_000))
    private let sender = QueueTestSender()
    private let base: Int64 = 1_800_000_000_000

    init() throws {
        folder = try QueueTestFolder()
    }

    private func makeQueue() -> PushDeliveryConfirmationQueue {
        makeTestQueue(folder: folder, sender: sender, clock: clock)
    }

    private func failTimes(_ count: Int, queue: PushDeliveryConfirmationQueue) async {
        (0..<count).forEach { _ in sender.enqueue(500) }
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        for sleeps in stride(from: 2, through: count, by: 1) {
            await queue.passAtNextAttempt(clock: clock)
            await clock.waitForSleeps(sleeps)
        }
    }

    private func throttledByExtension() async throws -> (queue: PushDeliveryConfirmationQueue, throttledAt: Int64) {
        let queue = makeQueue()
        clock.advance(by: 5)
        let throttledAt = queueTestMilliseconds(clock.now)
        try folder.write("a", receivedAt: base - 1000, lastStatusCode: 429, lastAttemptAt: throttledAt)
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        return (queue, throttledAt)
    }

    @Test("K10: a newer last-success lifts the pause and wake() sends right away")
    func lastSuccessLiftsPause() async throws {
        try folder.write("a", receivedAt: base - 1000)
        let queue = makeQueue()
        await failTimes(1, queue: queue)
        clock.advance(by: 1)
        try folder.writeLastSuccess(queueTestMilliseconds(clock.now))
        sender.enqueue(200)

        await queue.wakeAndWait()

        #expect(sender.urls == ["a", "a"].map(QueueTestFolder.url))
        #expect(await queue.pause == nil)
    }

    @Test("K36: last-success alone sends nothing until the pause timer fires")
    func lastSuccessWaitsForTimer() async throws {
        try folder.write("a", receivedAt: base - 1000)
        let queue = makeQueue()
        await failTimes(1, queue: queue)
        clock.advance(by: 1)
        try folder.writeLastSuccess(queueTestMilliseconds(clock.now))
        sender.enqueue(200)

        #expect(sender.calls.count == 1)

        clock.fireLatest(advancing: false)
        await sender.waitForCalls(2)

        #expect(sender.urls == ["a", "a"].map(QueueTestFolder.url))
        withExtendedLifetime(queue) {}
    }

    @Test("K14: 429 from the extension after the queue started holds the first request for 200 s")
    func extensionThrottleHoldsFirstRequest() async throws {
        let (queue, throttledAt) = try await throttledByExtension()

        #expect(clock.sleeps == [200])
        #expect(await queue.nextAttemptAt == throttledAt + 200_000)

        await queue.wakeAndWait()
        await clock.waitForSleeps(2)

        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .throttled, duration: 200))
        #expect(await queue.nextAttemptAt == throttledAt + 200_000)

        clock.set(milliseconds: throttledAt + 199_999)
        await queue.pass()
        await clock.waitForSleeps(3)

        #expect(sender.calls.isEmpty)

        clock.set(milliseconds: throttledAt + 200_000)
        await queue.pass()

        #expect(sender.calls.count == 1)
    }

    @Test("K16: 429 on the queue's own request after the extension's 429 sleeps 400")
    func ownThrottleContinuesExtensionThrottle() async throws {
        let (queue, _) = try await throttledByExtension()
        sender.enqueue(429)

        await queue.passAtNextAttempt(clock: clock)

        #expect(await clock.waitForSleeps(2).last == 400)
        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .throttled, duration: 400))
    }

    @Test("K32: 429 from the extension during a 320 s failure pause switches to throttle 200 and keeps the later time")
    func extensionThrottleDuringFailurePause() async throws {
        try folder.write("a", receivedAt: base - 1000)
        let queue = makeQueue()
        await failTimes(6, queue: queue)
        let failurePauseEnd = try #require(await queue.nextAttemptAt)
        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .failed, duration: 320))
        clock.advance(by: 10)
        try folder.write("b", receivedAt: base - 500, lastStatusCode: 429, lastAttemptAt: queueTestMilliseconds(clock.now))

        await queue.wakeAndWait()
        await clock.waitForSleeps(7)

        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .throttled, duration: 200))
        #expect(await queue.nextAttemptAt == failurePauseEnd)

        clock.set(milliseconds: failurePauseEnd - 1)
        await queue.pass()
        await clock.waitForSleeps(8)

        #expect(sender.calls.count == 6)

        sender.enqueue(429)
        await queue.passAtNextAttempt(clock: clock)

        #expect(sender.calls.count == 7)
        #expect(await clock.waitForSleeps(9).last == 400)
    }

    @Test("K35: last-success after the extension's 429 sends everything at once and the pauses start over")
    func lastSuccessAfterExtensionThrottle() async throws {
        try folder.write("a", receivedAt: base - 1000)
        let queue = makeQueue()
        await failTimes(4, queue: queue)
        clock.advance(by: 5)
        try folder.write("b", receivedAt: base - 500, lastStatusCode: 429, lastAttemptAt: queueTestMilliseconds(clock.now))
        try folder.write("c", receivedAt: base - 100)
        await queue.wakeAndWait()
        await clock.waitForSleeps(5)
        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .throttled, duration: 200))
        clock.advance(by: 1)
        try folder.writeLastSuccess(queueTestMilliseconds(clock.now))
        sender.enqueue(200, 200, 500, 429)

        await queue.wakeAndWait()

        #expect(await clock.waitForSleeps(6).last == 10)

        await queue.passAtNextAttempt(clock: clock)

        #expect(await clock.waitForSleeps(7).last == 200)
        let expected = Array(repeating: "a", count: 5) + ["b", "c", "c"]
        #expect(sender.urls == expected.map(QueueTestFolder.url))
    }

    @Test("K47: 429 from the extension dated a day ahead counts from now and a newer last-success still lifts it")
    func futureExtensionThrottleIsClamped() async throws {
        try folder.write("a", receivedAt: base - 1000, lastStatusCode: 429, lastAttemptAt: base + 86_400_000)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(await clock.waitForSleeps(1) == [200])
        #expect(await queue.nextAttemptAt == base + 200_000)
        #expect(sender.calls.isEmpty)

        clock.advance(by: 1)
        try folder.writeLastSuccess(queueTestMilliseconds(clock.now))
        await queue.wakeAndWait()

        #expect(sender.urls == [QueueTestFolder.url("a")])
        #expect(await queue.pause == nil)
    }

    @Test("K15: 429 from the extension before the queue started does not hold the request")
    func oldExtensionThrottleIsIgnored() async throws {
        try folder.write("a", receivedAt: base - 2000, lastStatusCode: 429, lastAttemptAt: base - 1000)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(sender.calls.count == 1)
        #expect(clock.sleeps.isEmpty)
    }
}
