//
//  PushDeliveryConfirmationQueueRestartTests.swift
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

@Suite("Push delivery confirmation queue: restart and cancellation")
struct PushDeliveryConfirmationQueueRestartTests {
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

    private struct Restarted {
        let queue: PushDeliveryConfirmationQueue
        let sender: QueueTestSender
        let clock: QueueTestClock
    }

    private func restarted(_ codes: Int?...) -> Restarted {
        let sender = QueueTestSender()
        codes.forEach { sender.enqueue($0) }
        let clock = QueueTestClock(now: self.clock.now)
        return Restarted(queue: makeTestQueue(folder: folder, sender: sender, clock: clock), sender: sender, clock: clock)
    }

    @Test("K18, K20, K38: a new queue after two failures sends right away and starts the pause from 10")
    func restartAfterFailures() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(500, 500)
        let queue = makeQueue()
        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        await queue.passAtNextAttempt(clock: clock)
        #expect(await clock.waitForSleeps(2) == [10, 20])

        let next = restarted(500)
        await next.queue.enableAndWait()

        #expect(next.sender.urls == [QueueTestFolder.url("a")])
        #expect(await next.clock.waitForSleeps(1) == [10])
    }

    @Test("K19: a new queue after a 429 pause sends right away and starts the throttle from 200")
    func restartAfterThrottle() async throws {
        try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(429)
        let queue = makeQueue()
        await queue.enableAndWait()
        #expect(await clock.waitForSleeps(1) == [200])

        let next = restarted(429)
        await next.queue.enableAndWait()

        #expect(next.sender.urls == [QueueTestFolder.url("a")])
        #expect(await next.clock.waitForSleeps(1) == [200])
    }

    @Test("K45: a record whose request got no answer is sent again by a new queue")
    func unansweredRecordIsResent() async throws {
        let file = try folder.write("a", receivedAt: base - 1000)
        let held = QueueTestSender(.hold)
        let queue = makeTestQueue(folder: folder, sender: held, clock: clock)
        queue.enable()
        await held.waitForCalls(1)

        #expect(folder.exists(file))

        let next = restarted(200)
        await next.queue.enableAndWait()

        #expect(next.sender.urls == [QueueTestFolder.url("a")])
        #expect(!folder.exists(file))
        queue.suspendPass()
    }

    @Test("Review Focus 1: wake() during a request makes the same pass pick up a record written meanwhile")
    func wakeDuringRequestRepeatsThePass() async throws {
        let first = try folder.write("a", receivedAt: base - 2000)
        let held = QueueTestSender(.hold, .status(200))
        let queue = makeTestQueue(folder: folder, sender: held, clock: clock)
        let enabled = Task { await queue.enableAndWait() }
        await held.waitForCalls(1)
        let woken = Task { await queue.wakeAndWait() }
        await queue.waitUntilRepeatRequested()
        let second = try folder.write("b", receivedAt: base - 1000)

        held.release(200)
        await enabled.value
        await woken.value

        #expect(held.urls == ["a", "b"].map(QueueTestFolder.url))
        #expect(!folder.exists(first))
        #expect(!folder.exists(second))
    }

    @Test("suspendPass() then wake() arriving in call order: the record is sent again after the cancellation")
    func suspendThenWakeInOrder() async throws {
        let file = try folder.write("a", receivedAt: base - 1000)
        let held = QueueTestSender(.hold, .status(200))
        let queue = makeTestQueue(folder: folder, sender: held, clock: clock)
        let enabled = Task { await queue.enableAndWait() }
        await held.waitForCalls(1)
        let suspendCall = queue.takeCall()
        let wakeCall = queue.takeCall()

        await queue.suspend(call: suspendCall)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { await queue.start(call: wakeCall, enabling: false) { continuation.resume() } }
        }
        await enabled.value

        #expect(held.calls.count == 2)
        #expect(!folder.exists(file))
    }

    @Test("suspendPass() then wake() arriving reversed: the earlier suspend does not cancel the later wake")
    func suspendThenWakeReversed() async throws {
        let file = try folder.write("a", receivedAt: base - 1000)
        let held = QueueTestSender(.hold)
        let queue = makeTestQueue(folder: folder, sender: held, clock: clock)
        let enabled = Task { await queue.enableAndWait() }
        await held.waitForCalls(1)
        let suspendCall = queue.takeCall()
        let wakeCall = queue.takeCall()
        let woken = Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Task { await queue.start(call: wakeCall, enabling: false) { continuation.resume() } }
            }
        }
        await queue.waitUntilRepeatRequested()

        await queue.suspend(call: suspendCall)

        #expect(await queue.repeatRequested)
        held.release(200)
        await enabled.value
        await woken.value
        #expect(held.calls.count == 1)
        #expect(!folder.exists(file))
    }

    @Test("K46: suspendPass() during a request keeps the record, the pause and drops the repeat")
    func suspendDuringRequest() async throws {
        let file = try folder.write("a", receivedAt: base - 1000)
        let held = QueueTestSender(.hold)
        let queue = makeTestQueue(folder: folder, sender: held, clock: clock)
        let enabled = Task { await queue.enableAndWait() }
        await held.waitForCalls(1)
        let woken = Task { await queue.wakeAndWait() }
        await queue.waitUntilRepeatRequested()

        queue.suspendPass()
        await enabled.value
        await woken.value

        #expect(folder.exists(file))
        #expect(held.calls.count == 1)
        #expect(await queue.pause == nil)
        #expect(await queue.nextAttemptAt == nil)
        #expect(await !queue.repeatRequested)
        #expect(clock.sleeps.isEmpty)
    }
}
