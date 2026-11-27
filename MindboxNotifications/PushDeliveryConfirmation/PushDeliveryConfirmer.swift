//
//  PushDeliveryConfirmer.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

final class PushDeliveryConfirmer: Sendable {

    static let maxAttempts = 3
    static let attemptInterval: TimeInterval = 3

    enum Outcome: Equatable {
        case delivered
        case rejected
        case retry
    }

    private let sender: PushDeliveryConfirmationSender
    private let store: PushDeliveryConfirmationStore?
    private let attemptInterval: TimeInterval
    private let now: @Sendable () -> Date

    init(
        sender: PushDeliveryConfirmationSender = PushDeliveryConfirmationSender(
            headers: PushDeliveryConfirmationHeaders.make()
        ),
        store: PushDeliveryConfirmationStore? = PushDeliveryConfirmationStore(),
        attemptInterval: TimeInterval = PushDeliveryConfirmer.attemptInterval,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sender = sender
        self.store = store
        self.attemptInterval = attemptInterval
        self.now = now
    }

    @discardableResult
    func start(_ confirmation: PushDeliveryConfirmation, completion: (@Sendable () -> Void)? = nil) -> Task<Void, Never> {
        try? store?.save(confirmation)
        let startedAt = ProcessInfo.processInfo.systemUptime
        return Task { [sender, store, attemptInterval, now] in
            var lastStatusCode: Int?
            for attempt in 0..<Self.maxAttempts {
                await Self.wait(untilUptime: startedAt + Double(attempt) * attemptInterval)
                lastStatusCode = await sender.send(confirmation, sentAt: now())
                switch Self.outcome(of: lastStatusCode) {
                case .delivered:
                    store?.remove(confirmation)
                    try? store?.markSuccess(at: now())
                    completion?()
                    return
                case .rejected:
                    store?.remove(confirmation)
                    completion?()
                    return
                case .retry:
                    continue
                }
            }
            try? store?.release(confirmation, lastStatusCode: lastStatusCode, lastAttemptAt: now())
            completion?()
        }
    }

    private static func wait(untilUptime uptime: TimeInterval) async {
        let remaining = uptime - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    static func outcome(of statusCode: Int?) -> Outcome {
        switch PushDeliveryConfirmationAnswer(statusCode: statusCode) {
        case .delivered:
            return .delivered
        case .rejected:
            return .rejected
        case .throttled, .failed:
            return .retry
        }
    }
}
