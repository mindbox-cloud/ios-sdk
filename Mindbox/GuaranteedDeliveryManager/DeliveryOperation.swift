//
//  DeliveryOperation.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class DeliveryOperation: AsyncOperation, @unchecked Sendable {
    private let event: Event

    private let databaseRepository: DatabaseRepositoryProtocol
    private let eventRepository: EventRepository
    private let pauseManager: DeliveryPauseManager
    private let retryDelayManager: DeliveryRetryDelayManager
    private let operationName: String
    private let operationKey: String

    init(
        databaseRepository: DatabaseRepositoryProtocol,
        eventRepository: EventRepository,
        event: Event,
        pauseManager: DeliveryPauseManager,
        retryDelayManager: DeliveryRetryDelayManager
    ) {
        self.databaseRepository = databaseRepository
        self.eventRepository = eventRepository
        self.event = event
        self.pauseManager = pauseManager
        self.retryDelayManager = retryDelayManager
        self.operationName = event.deliveryOperationName
        self.operationKey = event.deliveryOperationKey
    }

    var onCompleted: ((_ event: Event, _ error: MindboxError?) -> Void)?

    private func deliveryResult(after error: MindboxError) -> DeliveryResult {
        event.type == .trackingIdsUpdated ? .discarded : DeliveryResult(error: error)
    }

    override func main() {
        guard !isCancelled else { finish(); return }

        if let remaining = pauseManager.remainingPause(for: operationKey) {
            Logger.common(message: "[GD] decision: operation \(operationName) paused, postpone, \(Int(remaining.rounded(.up))) s left", level: .debug, category: .delivery)
            try? databaseRepository.update(event: event)
            retryDelayManager.registerPostponed(transactionId: event.transactionId, isRetry: event.isRetry)
            finish()
            return
        }

        Logger.common(message: "[DeliveryOperation] Sending event `\(event.type.rawValue)` with transactionId: \(event.transactionId))", level: .info, category: .delivery)

        eventRepository.send(event: event) { [weak self] result in
            guard let self else { return }
            defer { self.finish() }
            guard !self.isCancelled else { return }

            switch result {
            case .success:
                self.onCompleted?(self.event, nil)
                Logger.common(message: "[DeliveryOperation] Did send event `\(event.type.rawValue)` with transactionId: \(self.event.transactionId)", level: .info, category: .delivery)
                try? self.databaseRepository.delete(event: self.event)
                self.pauseManager.register(.delivered, for: self.operationKey)
                self.retryDelayManager.register(.delivered, transactionId: self.event.transactionId, isRetry: self.event.isRetry)
            case let .failure(error):
                self.onCompleted?(self.event, error)
                Logger.common(message: "[DeliveryOperation] Did send event `\(event.type.rawValue)` with transactionId: \(self.event.transactionId) failed with error: \(error.localizedDescription)",
                              level: .error, category: .delivery)

                guard !self.isCancelled else { return }

                self.handle(self.deliveryResult(after: error), of: error)
            }
        }
    }

    private func handle(_ result: DeliveryResult, of error: MindboxError) {
        let decision = result.isRemovedFromQueue ? "delete" : "keep"
        Logger.common(message: "[GD] decision: \(error.deliveryDescription) → \(decision)", level: .info, category: .delivery)

        if result.isRemovedFromQueue {
            try? databaseRepository.delete(event: event)
        } else {
            try? databaseRepository.update(event: event)
        }

        retryDelayManager.register(result, transactionId: event.transactionId, isRetry: event.isRetry)

        guard let pause = pauseManager.register(result, for: operationKey) else { return }
        Logger.common(message: "[GD] decision: operation \(operationName) throttled, skip for \(Int(pause.rounded())) s", level: .info, category: .delivery)
    }
}

enum DeliveryResult: Equatable {
    case delivered
    case discarded
    case throttled
    case serverFailure
    case noResponse
    case retryLater

    init(error: MindboxError) {
        switch error {
        case let .protocolError(response) where response.httpStatusCode == DeliveryResult.tooManyRequests:
            self = .throttled
        case let .protocolError(response) where HTTPURLResponseStatusCodeValidator(statusCode: response.httpStatusCode).isClientError:
            self = .discarded
        case .serverError:
            self = .serverFailure
        case .connectionError:
            self = .noResponse
        default:
            self = .retryLater
        }
    }

    var isRemovedFromQueue: Bool {
        self == .delivered || self == .discarded
    }

    private static let tooManyRequests = 429
}

final class DeliveryPauseManager {

    private struct OperationState {
        var pausedUntil: TimeInterval
        var nextPause: TimeInterval
    }

    private let firstPause: TimeInterval
    private let maxPause: TimeInterval
    private let now: () -> TimeInterval
    private let lock = NSLock()
    private var states: [String: OperationState] = [:]

    init(
        firstPause: TimeInterval = 180,
        maxPause: TimeInterval = 3600,
        now: @escaping () -> TimeInterval = DeliveryPauseManager.monotonicTime
    ) {
        self.firstPause = firstPause
        self.maxPause = maxPause
        self.now = now
    }

    static func monotonicTime() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / TimeInterval(NSEC_PER_SEC)
    }

    func remainingPause(for key: String) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        guard let pausedUntil = states[key]?.pausedUntil else { return nil }
        let remaining = pausedUntil - now()
        return remaining > 0 ? remaining : nil
    }

    @discardableResult
    func register(_ result: DeliveryResult, for key: String) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        switch result {
        case .delivered, .discarded:
            states[key] = nil
            return nil
        case .throttled:
            let pause = states[key]?.nextPause ?? firstPause
            states[key] = OperationState(
                pausedUntil: now() + pause,
                nextPause: min(pause * 2, maxPause)
            )
            return pause
        case .serverFailure, .noResponse, .retryLater:
            return nil
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        states.removeAll()
    }
}

final class DeliveryRetryDelayManager {

    private let firstDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let lock = NSLock()
    private var delay: TimeInterval
    private var serverFailedTransactionIds: Set<String> = []
    private var retriedInRoundTransactionIds: Set<String> = []
    private var postponedBeforeFirstAttemptTransactionIds: Set<String> = []

    init(firstDelay: TimeInterval = 60, maxDelay: TimeInterval = 3600) {
        self.firstDelay = firstDelay
        self.maxDelay = max(firstDelay, maxDelay)
        self.delay = firstDelay
    }

    var current: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return delay
    }

    var trackedTransactionIds: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return serverFailedTransactionIds.union(postponedBeforeFirstAttemptTransactionIds)
    }

    func register(_ result: DeliveryResult, transactionId: String, isRetry: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let wasPostponedBeforeFirstAttempt = postponedBeforeFirstAttemptTransactionIds.remove(transactionId) != nil
        let isFirstAttempt = !isRetry || wasPostponedBeforeFirstAttempt
        switch result {
        case .serverFailure:
            serverFailedTransactionIds.insert(transactionId)
            guard !isFirstAttempt, !retriedInRoundTransactionIds.insert(transactionId).inserted else { return }
            growDelay()
            retriedInRoundTransactionIds = [transactionId]
        case .delivered, .discarded, .throttled, .retryLater:
            removeServerFailure(of: transactionId)
        case .noResponse:
            break
        }
    }

    func registerPostponed(transactionId: String, isRetry: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if !isRetry {
            postponedBeforeFirstAttemptTransactionIds.insert(transactionId)
        }
        removeServerFailure(of: transactionId)
    }

    func forget(transactionIds: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        postponedBeforeFirstAttemptTransactionIds.subtract(transactionIds)
        serverFailedTransactionIds.intersection(transactionIds).forEach(removeServerFailure)
    }

    func completeRound() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        if !retriedInRoundTransactionIds.isEmpty {
            growDelay()
            retriedInRoundTransactionIds.removeAll()
        }
        return delay
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        serverFailedTransactionIds.removeAll()
        retriedInRoundTransactionIds.removeAll()
        postponedBeforeFirstAttemptTransactionIds.removeAll()
        delay = firstDelay
    }

    private func growDelay() {
        delay = min(delay * 2, maxDelay)
    }

    private func removeServerFailure(of transactionId: String) {
        serverFailedTransactionIds.remove(transactionId)
        retriedInRoundTransactionIds.remove(transactionId)
        guard serverFailedTransactionIds.isEmpty else { return }
        retriedInRoundTransactionIds.removeAll()
        delay = firstDelay
    }
}

extension Event {
    var deliveryOperationName: String {
        guard type == .customEvent, let custom = BodyDecoder<CustomEvent>(decodable: body)?.body else {
            return type.rawValue
        }
        return custom.name
    }

    var deliveryOperationKey: String {
        "\(type.rawValue) \(deliveryOperationName)"
    }
}

private extension MindboxError {
    var deliveryDescription: String {
        switch self {
        case let .protocolError(response), let .serverError(response):
            return "HTTP \(response.httpStatusCode)"
        case let .invalidResponse(response as HTTPURLResponse):
            return "HTTP \(response.statusCode)"
        case .validationError:
            return "validation error"
        case .connectionError:
            return "no response"
        default:
            return "error"
        }
    }
}
