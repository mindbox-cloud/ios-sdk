//
//  PushDeliveryConfirmationQueuePauseTests.swift
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

@Suite("Push delivery confirmation queue: pauses")
struct PushDeliveryConfirmationQueuePauseTests {
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

    private func sleeps(after codes: [Int?]) async throws -> [TimeInterval] {
        try folder.write("a", receivedAt: base - 1000)
        codes.forEach { sender.enqueue($0) }
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        for count in codes.indices.dropFirst() {
            await queue.passAtNextAttempt(clock: clock)
            await clock.waitForSleeps(count + 1)
        }
        return clock.sleeps
    }

    @Test("K7: 500, 500, 500 sleep 10, 20, 40")
    func failuresDouble() async throws {
        #expect(try await sleeps(after: [500, 500, 500]) == [10, 20, 40])
    }

    @Test("K9, K51: 500 and then no answer sleep 10, 20")
    func noAnswerCountsAsFailure() async throws {
        #expect(try await sleeps(after: [500, nil]) == [10, 20])
    }

    @Test("K13: 429, 429 sleep 200, 400")
    func throttlesDouble() async throws {
        #expect(try await sleeps(after: [429, 429]) == [200, 400])
    }

    @Test("Acceptance 4.4: the throttle pause stops at 3600")
    func throttleIsCapped() async throws {
        let codes: [Int?] = Array(repeating: 429, count: 7)
        #expect(try await sleeps(after: codes) == [200, 400, 800, 1600, 3200, 3600, 3600])
    }

    @Test("K33: 429 then 500 sleep 200, 10")
    func failureAfterThrottle() async throws {
        #expect(try await sleeps(after: [429, 500]) == [200, 10])
    }

    @Test("K39: 429, 500, 429 sleep 200, 10, 200")
    func throttleAfterFailureStartsOver() async throws {
        #expect(try await sleeps(after: [429, 500, 429]) == [200, 10, 200])
    }

    @Test("K40, K41: ten 500 then 429 sleeps 200, then 500 sleeps 10")
    func longFailuresThenThrottleThenFailure() async throws {
        let codes: [Int?] = Array(repeating: 500, count: 10) + [429, 500]
        let sleeps = try await sleeps(after: codes)
        #expect(Array(sleeps.suffix(2)) == [200, 10])
    }

    @Test("K42: ten 500 then 429, 429 sleep 200, 400")
    func longFailuresThenThrottles() async throws {
        let codes: [Int?] = Array(repeating: 500, count: 10) + [429, 429]
        let sleeps = try await sleeps(after: codes)
        #expect(Array(sleeps.suffix(2)) == [200, 400])
    }

    @Test("K12: the pause ends with 200 and the next record starts from 10 without a sleep in between")
    func successResetsPauseForNextRecord() async throws {
        try folder.write("a", receivedAt: base - 2000)
        try folder.write("b", receivedAt: base - 1000)
        sender.enqueue(500, 500, 200, 500)
        let queue = makeQueue()

        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        await queue.passAtNextAttempt(clock: clock)
        await clock.waitForSleeps(2)
        await queue.passAtNextAttempt(clock: clock)

        #expect(await clock.waitForSleeps(3) == [10, 20, 10])
        #expect(sender.urls == ["a", "a", "a", "b"].map(QueueTestFolder.url))
    }

    @Test("K50: 500 then 404 on the first record and 500 on the second sleep 10 and 10 again")
    func rejectionResetsPause() async throws {
        try folder.write("a", receivedAt: base - 2000)
        try folder.write("b", receivedAt: base - 1000)
        sender.enqueue(500, 404, 500)
        let queue = makeQueue()

        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        await queue.passAtNextAttempt(clock: clock)

        #expect(await clock.waitForSleeps(2) == [10, 10])
        #expect(sender.urls == ["a", "a", "b"].map(QueueTestFolder.url))
    }

    @Test("K8: repeated wake() during a pause sends nothing")
    func wakeDuringPauseSendsNothing() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(500)
        let queue = makeQueue()
        await queue.enableAndWait()
        let nextAttemptAt = await queue.nextAttemptAt

        await queue.wakeAndWait()
        clock.advance(by: 9)
        await queue.wakeAndWait()

        #expect(sender.calls.count == 1)
        #expect(await queue.nextAttemptAt == nextAttemptAt)
        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .failed, duration: 10))
    }

    @Test("K11: a new record with 500 from the extension does not change the pause")
    func extensionFailureKeepsPause() async throws {
        try folder.write("a", receivedAt: base - 2000)
        sender.enqueue(500, 500)
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        let nextAttemptAt = await queue.nextAttemptAt
        clock.advance(by: 1)
        try folder.write("b", receivedAt: base - 1000, lastStatusCode: 500, lastAttemptAt: queueTestMilliseconds(clock.now))

        await queue.wakeAndWait()
        await clock.waitForSleeps(2)

        #expect(sender.calls.count == 1)
        #expect(await queue.nextAttemptAt == nextAttemptAt)
        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .failed, duration: 10))

        await queue.passAtNextAttempt(clock: clock)

        #expect(sender.urls == ["a", "a"].map(QueueTestFolder.url))
        #expect(await queue.pause == PushDeliveryConfirmationPause(answer: .failed, duration: 20))
        #expect(await clock.waitForSleeps(3).last == 20)
    }

    @Test("K47: a next attempt a day ahead sleeps 4500 and the request goes out when that timer fires")
    func longWaitIsCapped() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(500, 200)
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        clock.advance(by: -86_400)

        await queue.wakeAndWait()

        #expect(await clock.waitForSleeps(2) == [10, 4500])
        #expect(await queue.nextAttemptAt == queueTestMilliseconds(clock.now) + 4_500_000)
        #expect(sender.calls.count == 1)

        clock.fireLatest(advancing: true)
        await sender.waitForCalls(2)

        #expect(sender.urls == ["a", "a"].map(QueueTestFolder.url))
    }
}
