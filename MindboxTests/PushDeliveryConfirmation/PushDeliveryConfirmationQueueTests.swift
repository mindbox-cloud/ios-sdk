//
//  PushDeliveryConfirmationQueueTests.swift
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

@Suite("Push delivery confirmation queue: start and order")
struct PushDeliveryConfirmationQueueTests {
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

    @Test("K44: before enable() nothing is sent and the completion is called")
    func nothingBeforeEnable() async throws {
        try folder.write("a", receivedAt: base - 1000)
        let queue = makeQueue()

        await queue.wakeAndWait()

        #expect(sender.calls.isEmpty)
        #expect(queue.hasRecords)
    }

    @Test("K31: without an inbox nothing is sent and the completion is called")
    func nothingWithoutInbox() async throws {
        try folder.write("a", receivedAt: base - 1000)
        let queue = makeTestQueue(folder: nil, sender: sender, clock: clock)

        await queue.enableAndWait()
        await queue.wakeAndWait()

        #expect(sender.calls.isEmpty)
        #expect(!queue.hasRecords)
    }

    @Test("K2: a queue without a pause sends on wake() right away")
    func sendsRightAway() async throws {
        let queue = makeQueue()
        await queue.enableAndWait()
        try folder.write("a", receivedAt: base - 1000)

        await queue.wakeAndWait()

        #expect(sender.urls == [QueueTestFolder.url("a")])
        #expect(sender.calls.first?.sentAt == clock.now)
        #expect(clock.sleeps.isEmpty)
    }

    @Test("K3: 200 gives one request, deletes the file and carries sentAt - receivedAt")
    func deliveredDeletesFile() async throws {
        let file = try folder.write("a", receivedAt: base - 5000)
        sender.enqueue(200)
        let queue = makeQueue()

        await queue.enableAndWait()
        await queue.wakeAndWait()

        let call = try #require(sender.calls.first)
        #expect(sender.calls.count == 1)
        #expect(!folder.exists(file))
        #expect(call.confirmation.receivedAt == Date(timeIntervalSince1970: TimeInterval(base - 5000) / 1000))
        #expect(call.sentAt == clock.now)
        let query = call.confirmation.request(sentAt: call.sentAt, headers: [:]).url?.query ?? ""
        #expect(query.contains("dateTimeOffset=5000"))
    }

    @Test("K4, K59: 404 and 302 delete the file and the record is not sent again", arguments: [404, 302])
    func rejectedDeletesFile(statusCode: Int) async throws {
        let file = try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(statusCode)
        let queue = makeQueue()

        await queue.enableAndWait()
        await queue.wakeAndWait()

        #expect(!folder.exists(file))
        #expect(sender.calls.count == 1)
        #expect(await queue.pause == nil)
    }

    @Test("K53: three records with 200 are sent in receivedAt order without any sleep")
    func sendsAllInOrder() async throws {
        let files = [
            try folder.write("c", receivedAt: base - 1000),
            try folder.write("a", receivedAt: base - 3000),
            try folder.write("b", receivedAt: base - 2000)
        ]
        sender.enqueue(200, 200, 200)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(sender.urls == ["a", "b", "c"].map(QueueTestFolder.url))
        #expect(files.allSatisfy { !folder.exists($0) })
        #expect(clock.sleeps.isEmpty)
    }

    @Test("K5, K17: a failure on the first record leaves the second and third untouched", arguments: [500, 429])
    func failureStopsThePass(statusCode: Int) async throws {
        let files = [
            try folder.write("a", receivedAt: base - 3000),
            try folder.write("b", receivedAt: base - 2000),
            try folder.write("c", receivedAt: base - 1000)
        ]
        sender.enqueue(statusCode)
        let queue = makeQueue()

        await queue.enableAndWait()

        #expect(sender.urls == [QueueTestFolder.url("a")])
        #expect(files.allSatisfy { folder.exists($0) })
    }

    @Test("K27: while the first record keeps failing, the second is never sent in five passes")
    func failingHeadBlocksTheRest() async throws {
        try folder.write("a", receivedAt: base - 2000)
        try folder.write("b", receivedAt: base - 1000)
        sender.enqueue(500, 500, 500, 500, 500)
        let queue = makeQueue()

        await queue.enableAndWait()
        await clock.waitForSleeps(1)
        for count in 2...5 {
            await queue.passAtNextAttempt(clock: clock)
            await clock.waitForSleeps(count)
        }

        #expect(sender.urls == Array(repeating: QueueTestFolder.url("a"), count: 5))
    }

    @Test("K25, K36: a record written after an empty pass waits for the next wake()")
    func newRecordWaitsForWake() async throws {
        let queue = makeQueue()
        await queue.enableAndWait()

        try folder.write("a", receivedAt: base - 1000)

        #expect(sender.calls.isEmpty)
        #expect(queue.hasRecords)

        await queue.wakeAndWait()

        #expect(sender.urls == [QueueTestFolder.url("a")])
    }

    @Test("Acceptance 2.6: by the time the wake() completion is called the request is sent and the file deleted")
    func wakeCompletionAfterDelivery() async throws {
        let queue = makeQueue()
        await queue.enableAndWait()
        let file = try folder.write("a", receivedAt: base - 1000)
        let sender = sender
        let folder = folder

        let state: (calls: Int, exists: Bool) = await withCheckedContinuation { continuation in
            queue.wake { continuation.resume(returning: (sender.calls.count, folder.exists(file))) }
        }

        #expect(state.calls == 1)
        #expect(!state.exists)
    }

    @Test("K21, K37: wake() during a pause completes at once without requests, after the pause the request goes out")
    func wakeDuringPauseCompletesAtOnce() async throws {
        let file = try folder.write("a", receivedAt: base - 1000)
        sender.enqueue(500, 200)
        let queue = makeQueue()
        await queue.enableAndWait()
        let nextAttemptAt = try #require(await queue.nextAttemptAt)

        await queue.wakeAndWait()

        #expect(sender.calls.count == 1)
        #expect(folder.exists(file))

        clock.set(milliseconds: nextAttemptAt)
        await queue.wakeAndWait()

        #expect(sender.urls == ["a", "a"].map(QueueTestFolder.url))
        #expect(!folder.exists(file))
    }

    @Test("K46: suspendPass() during a request started by wake() calls the completion and does not grow the pause")
    func suspendDuringWakeRequest() async throws {
        let held = QueueTestSender(.hold)
        let queue = makeTestQueue(folder: folder, sender: held, clock: clock)
        await queue.enableAndWait()
        let file = try folder.write("a", receivedAt: base - 1000)
        let woken = Task { await queue.wakeAndWait() }
        await held.waitForCalls(1)

        queue.suspendPass()
        await woken.value

        #expect(folder.exists(file))
        #expect(held.calls.count == 1)
        #expect(await queue.pause == nil)
        #expect(await queue.nextAttemptAt == nil)
        #expect(clock.sleeps.isEmpty)
    }

    @Test("K23: hasRecords follows the folder")
    func hasRecordsFollowsFolder() async throws {
        let queue = makeQueue()
        await queue.enableAndWait()

        #expect(!queue.hasRecords)

        try folder.write("a", receivedAt: base - 1000)

        #expect(queue.hasRecords)

        await queue.wakeAndWait()

        #expect(!queue.hasRecords)
    }
}
