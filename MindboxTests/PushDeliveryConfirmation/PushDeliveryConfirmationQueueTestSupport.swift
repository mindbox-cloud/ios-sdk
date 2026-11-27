//
//  PushDeliveryConfirmationQueueTestSupport.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
@_spi(Internal) @testable import Mindbox
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

final class QueueTestClock: @unchecked Sendable {
    private struct Sleeper {
        let id: UUID
        let delay: TimeInterval
        let continuation: CheckedContinuation<Void, Never>
    }

    private let lock = NSLock()
    private var current: Date
    private var log: [TimeInterval] = []
    private var sleepers: [Sleeper] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(now: Date) {
        current = now
    }

    var now: Date {
        lock.withLock { current }
    }

    var sleeps: [TimeInterval] {
        lock.withLock { log }
    }

    func set(_ date: Date) {
        lock.withLock { current = date }
    }

    func set(milliseconds: Int64) {
        set(Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000))
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }

    func sleep(_ delay: TimeInterval) async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let result: (cancelled: Bool, ready: [CheckedContinuation<Void, Never>]) = lock.withLock {
                    log.append(delay)
                    let ready = takeReadyWaiters()
                    guard !Task.isCancelled else { return (true, ready) }
                    sleepers.append(Sleeper(id: id, delay: delay, continuation: continuation))
                    return (false, ready)
                }
                result.ready.forEach { $0.resume() }
                if result.cancelled {
                    continuation.resume()
                }
            }
        } onCancel: {
            let sleeper: Sleeper? = lock.withLock {
                guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return sleepers.remove(at: index)
            }
            sleeper?.continuation.resume()
        }
    }

    func fireLatest(advancing: Bool) {
        let sleeper: Sleeper? = lock.withLock {
            guard let sleeper = sleepers.popLast() else { return nil }
            if advancing {
                current = current.addingTimeInterval(sleeper.delay)
            }
            return sleeper
        }
        sleeper?.continuation.resume()
    }

    @discardableResult
    func waitForSleeps(_ count: Int) async -> [TimeInterval] {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let ready: Bool = lock.withLock {
                guard log.count < count else { return true }
                waiters.append((count, continuation))
                return false
            }
            if ready {
                continuation.resume()
            }
        }
        return sleeps
    }

    private func takeReadyWaiters() -> [CheckedContinuation<Void, Never>] {
        let ready = waiters.filter { $0.count <= log.count }.map(\.continuation)
        waiters.removeAll { $0.count <= log.count }
        return ready
    }
}

final class QueueTestSender: PushDeliveryConfirmationSending, @unchecked Sendable {
    enum Reply {
        case status(Int?)
        case hold
    }

    struct Call {
        let confirmation: PushDeliveryConfirmation
        let sentAt: Date
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private var log: [Call] = []
    private var held: CheckedContinuation<Int?, Never>?
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(_ replies: Reply...) {
        self.replies = replies
    }

    var calls: [Call] {
        lock.withLock { log }
    }

    var urls: [String] {
        calls.map { $0.confirmation.url.absoluteString }
    }

    func enqueue(_ codes: Int?...) {
        lock.withLock { replies.append(contentsOf: codes.map { .status($0) }) }
    }

    func send(_ confirmation: PushDeliveryConfirmation, sentAt: Date) async -> Int? {
        let result: (reply: Reply, ready: [CheckedContinuation<Void, Never>]) = lock.withLock {
            log.append(Call(confirmation: confirmation, sentAt: sentAt))
            let reply = replies.isEmpty ? .status(200) : replies.removeFirst()
            let ready = waiters.filter { $0.count <= log.count }.map(\.continuation)
            waiters.removeAll { $0.count <= log.count }
            return (reply, ready)
        }
        result.ready.forEach { $0.resume() }
        guard case let .status(code) = result.reply else {
            return await hold()
        }
        return code
    }

    func release(_ code: Int?) {
        let continuation: CheckedContinuation<Int?, Never>? = lock.withLock {
            defer { held = nil }
            return held
        }
        continuation?.resume(returning: code)
    }

    func waitForCalls(_ count: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let ready: Bool = lock.withLock {
                guard log.count < count else { return true }
                waiters.append((count, continuation))
                return false
            }
            if ready {
                continuation.resume()
            }
        }
    }

    private func hold() async -> Int? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
                let cancelled: Bool = lock.withLock {
                    guard !Task.isCancelled else { return true }
                    held = continuation
                    return false
                }
                if cancelled {
                    continuation.resume(returning: nil)
                }
            }
        } onCancel: {
            release(nil)
        }
    }
}

struct QueueTestFolder {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QueueTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var inbox: PushDeliveryConfirmationInbox {
        PushDeliveryConfirmationInbox(directory: directory)
    }

    static func url(_ name: String) -> String {
        "https://example.com/confirm?id=\(name)"
    }

    @discardableResult
    func write(_ name: String, receivedAt: Int64, lastStatusCode: Int? = nil, lastAttemptAt: Int64? = nil) throws -> URL {
        let record = PushDeliveryConfirmationRecord(
            url: Self.url(name),
            receivedAt: receivedAt,
            lastStatusCode: lastStatusCode,
            lastAttemptAt: lastAttemptAt
        )
        let file = directory.appendingPathComponent(name).appendingPathExtension(PushDeliveryConfirmationRecord.releasedExtension)
        try JSONEncoder().encode(record).write(to: file)
        return file
    }

    func writeLastSuccess(_ milliseconds: Int64) throws {
        let marker = directory.appendingPathComponent(PushDeliveryConfirmationRecord.successMarkerName)
        try Data(String(milliseconds).utf8).write(to: marker)
    }

    func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path)
    }
}

func queueTestMilliseconds(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
}

func makeTestQueue(
    folder: QueueTestFolder?,
    sender: QueueTestSender,
    clock: QueueTestClock
) -> PushDeliveryConfirmationQueue {
    PushDeliveryConfirmationQueue(
        inbox: folder?.inbox,
        sender: sender,
        schedule: PushDeliveryConfirmationSchedule(random: { _ in 1 }),
        now: { clock.now },
        sleep: { await clock.sleep($0) }
    )
}

extension PushDeliveryConfirmationQueue {
    nonisolated func enableAndWait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            enable { continuation.resume() }
        }
    }

    nonisolated func wakeAndWait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            wake { continuation.resume() }
        }
    }

    func passAtNextAttempt(clock: QueueTestClock) async {
        if let nextAttemptAt {
            clock.set(milliseconds: nextAttemptAt)
        }
        await pass()
    }

    func waitUntilRepeatRequested() async {
        while !repeatRequested {
            await Task.yield()
        }
    }
}
