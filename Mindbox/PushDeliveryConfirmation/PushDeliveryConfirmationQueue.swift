//
//  PushDeliveryConfirmationQueue.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

protocol PushDeliveryConfirmationSending: Sendable {
    func send(_ confirmation: PushDeliveryConfirmation, sentAt: Date) async -> Int?
}

extension PushDeliveryConfirmationSender: PushDeliveryConfirmationSending {}

actor PushDeliveryConfirmationQueue {

    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value: UInt64 = 0

        func next() -> UInt64 {
            lock.withLock {
                value += 1
                return value
            }
        }
    }

    private let callCounter = CallCounter()
    private let inbox: PushDeliveryConfirmationInbox?
    private let sender: PushDeliveryConfirmationSending
    private let schedule: PushDeliveryConfirmationSchedule
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let startedAt: Int64

    private(set) var pause: PushDeliveryConfirmationPause?
    private(set) var nextAttemptAt: Int64?
    private(set) var updatedAt: Int64 = 0
    private(set) var repeatRequested = false

    private var isEnabled = false
    private var lastWakeCall: UInt64 = 0
    private var extensionThrottleAt: Int64?
    private var isPassing = false
    private var isPassSuspended = false
    private var completions: [@Sendable () -> Void] = []
    private var sendTask: Task<Int?, Never>?
    private var timerTask: Task<Void, Never>?
    private var timerID: UUID?

    init(
        inbox: PushDeliveryConfirmationInbox?,
        sender: PushDeliveryConfirmationSending,
        schedule: PushDeliveryConfirmationSchedule = .init(),
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
    ) {
        self.inbox = inbox
        self.sender = sender
        self.schedule = schedule
        self.now = now
        self.sleep = sleep
        self.startedAt = Self.milliseconds(now())
    }

    deinit {
        timerTask?.cancel()
        sendTask?.cancel()
    }

    nonisolated var hasRecords: Bool {
        inbox?.hasRecords ?? false
    }

    nonisolated func enable(completion: (@Sendable () -> Void)? = nil) {
        let call = takeCall()
        Task { await self.start(call: call, enabling: true, completion: completion) }
    }

    nonisolated func wake(completion: (@Sendable () -> Void)? = nil) {
        let call = takeCall()
        Task { await self.start(call: call, enabling: false, completion: completion) }
    }

    nonisolated func suspendPass() {
        let call = takeCall()
        Task { await self.suspend(call: call) }
    }

    nonisolated func takeCall() -> UInt64 {
        callCounter.next()
    }

    func pass() async {
        guard isEnabled, let inbox else {
            callCompletions()
            return
        }
        guard !isPassing else {
            repeatRequested = true
            return
        }
        isPassing = true
        repeat {
            repeatRequested = false
            isPassSuspended = false
            await sendDue(from: inbox)
        } while repeatRequested
        isPassing = false
        callCompletions()
    }

    func start(call: UInt64, enabling: Bool, completion: (@Sendable () -> Void)?) async {
        lastWakeCall = max(lastWakeCall, call)
        if enabling {
            isEnabled = true
        }
        if let completion {
            completions.append(completion)
        }
        await pass()
    }

    func suspend(call: UInt64) {
        guard call > lastWakeCall else { return }
        isPassSuspended = true
        repeatRequested = false
        sendTask?.cancel()
    }

    private func callCompletions() {
        let ready = completions
        completions = []
        ready.forEach { $0() }
    }

    private func sendDue(from inbox: PushDeliveryConfirmationInbox) async {
        if let lastSuccess = inbox.lastSuccess(), lastSuccess > updatedAt {
            clearPause()
            updatedAt = lastSuccess
        }

        let items = inbox.items(now: now()).items
        guard !items.isEmpty else {
            clearPause()
            return
        }

        let current = Self.milliseconds(now())
        applyExtensionThrottle(in: items, now: current)

        if let next = nextAttemptAt, next > current {
            let limit = current + Self.milliseconds(PushDeliveryConfirmationSchedule.maxWait)
            nextAttemptAt = min(next, limit)
            scheduleTimer(after: TimeInterval(min(next, limit) - current) / 1000)
            return
        }

        for item in items {
            let answer = await send(item)
            guard !isPassSuspended else { return }
            let answeredAt = Self.milliseconds(now())
            switch answer {
            case .delivered, .rejected:
                inbox.remove(item)
                clearPause()
                updatedAt = answeredAt
            case .throttled, .failed:
                let next = schedule.nextPause(after: answer, previous: pause)
                let wait = next.map(schedule.wait) ?? 0
                pause = next
                nextAttemptAt = answeredAt + Self.milliseconds(wait)
                updatedAt = answeredAt
                scheduleTimer(after: wait)
                return
            }
        }
    }

    private func applyExtensionThrottle(in items: [PushDeliveryConfirmationInbox.Item], now current: Int64) {
        let reportedAt = items
            .filter { $0.record.lastStatusCode == 429 }
            .compactMap { $0.record.lastAttemptAt }
            .max()
        guard let reportedAt, reportedAt > updatedAt, reportedAt > startedAt, reportedAt != extensionThrottleAt,
              let next = schedule.nextPause(after: .throttled, previous: pause) else {
            return
        }
        let throttledAt = min(reportedAt, current)
        extensionThrottleAt = reportedAt
        pause = next
        nextAttemptAt = max(nextAttemptAt ?? 0, throttledAt + Self.milliseconds(schedule.wait(for: next)))
        updatedAt = throttledAt
    }

    private func clearPause() {
        pause = nil
        nextAttemptAt = nil
        timerTask?.cancel()
        timerTask = nil
        timerID = nil
    }

    private func send(_ item: PushDeliveryConfirmationInbox.Item) async -> PushDeliveryConfirmationAnswer {
        let receivedAt = Date(timeIntervalSince1970: TimeInterval(item.record.receivedAt) / 1000)
        guard let confirmation = PushDeliveryConfirmation(deliveredUrl: item.record.url, receivedAt: receivedAt) else {
            return .rejected
        }
        let sender = sender
        let sentAt = now()
        let task = Task { await sender.send(confirmation, sentAt: sentAt) }
        sendTask = task
        let statusCode = await task.value
        sendTask = nil
        return PushDeliveryConfirmationAnswer(statusCode: statusCode)
    }

    private func scheduleTimer(after delay: TimeInterval) {
        timerTask?.cancel()
        let sleep = sleep
        let id = UUID()
        timerID = id
        timerTask = Task { [weak self] in
            await sleep(delay)
            guard !Task.isCancelled else { return }
            await self?.fireTimer(id)
        }
    }

    private func fireTimer(_ id: UUID) async {
        guard timerID == id else { return }
        timerTask = nil
        timerID = nil
        await pass()
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        milliseconds(date.timeIntervalSince1970)
    }

    private static func milliseconds(_ interval: TimeInterval) -> Int64 {
        Int64((interval * 1000).rounded())
    }
}
