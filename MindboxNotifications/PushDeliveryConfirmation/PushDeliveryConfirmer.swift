//
//  PushDeliveryConfirmer.swift
//  MindboxNotifications
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class PushDeliveryConfirmer: Sendable {

    static let maxAttempts = 3

    enum Outcome: Equatable {
        case delivered
        case rejected
        case retry
    }

    private let sender: PushDeliveryConfirmationSender
    private let store: PushDeliveryConfirmationStore?
    private let now: @Sendable () -> Date
    private let signal: @Sendable () -> Void

    init(
        sender: PushDeliveryConfirmationSender = PushDeliveryConfirmationSender(),
        store: PushDeliveryConfirmationStore? = PushDeliveryConfirmationStore(),
        now: @escaping @Sendable () -> Date = { Date() },
        signal: @escaping @Sendable () -> Void = { PushDeliveryConfirmationSignal.post() }
    ) {
        self.sender = sender
        self.store = store
        self.now = now
        self.signal = signal
    }

    @discardableResult
    func start(_ confirmation: PushDeliveryConfirmation, completion: (@Sendable () -> Void)? = nil) -> Task<Void, Never> {
        try? store?.save(confirmation)
        return Task { [sender, store, now, signal] in
            var lastStatusCode: Int?
            for _ in 0..<Self.maxAttempts {
                lastStatusCode = await sender.send(confirmation, sentAt: now())
                switch Self.outcome(of: lastStatusCode) {
                case .delivered:
                    store?.remove(confirmation)
                    try? store?.markSuccess(at: now())
                    signal()
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
            signal()
            completion?()
        }
    }

    static func outcome(of statusCode: Int?) -> Outcome {
        guard let statusCode else { return .retry }
        switch statusCode {
        case 200..<300:
            return .delivered
        case 300..<500 where statusCode != 429:
            return .rejected
        default:
            return .retry
        }
    }
}
