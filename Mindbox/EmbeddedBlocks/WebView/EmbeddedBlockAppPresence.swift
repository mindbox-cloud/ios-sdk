//
//  EmbeddedBlockAppPresence.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import QuartzCore
import MindboxLogger

protocol EmbeddedBlockAppPresenceSubscribing: AnyObject {

    func appDidEnterBackground()

    func userDidBecomePresent()

    func sessionCheckEndedWhileNotActive()

    func sessionChecked(startedAt: TimeInterval?, startsNewSession: Bool)

    func userReturned()
}

extension EmbeddedBlockAppPresenceSubscribing {

    func appDidEnterBackground() {}

    func userDidBecomePresent() {}

    func sessionCheckEndedWhileNotActive() {}

    func sessionChecked(startedAt: TimeInterval?, startsNewSession: Bool) {}

    func userReturned() {}
}

final class EmbeddedBlockAppPresence {

    static let shared = EmbeddedBlockAppPresence()

    var isPresent: Bool { applicationState() == .active && !isAwaitingSessionCheck }

    var isAwaitingSessionCheck: Bool { returnedAt != nil }

    private var returnedAt: TimeInterval?

    private var hasBeenInBackground = false

    private var isReturnUnannounced = false

    private var subscribers: [WeakSubscriber] = []

    private let applicationState: () -> UIApplication.State

    private let isSDKInitialized: () -> Bool

    private let now: () -> TimeInterval

    private let notificationCenter: NotificationCenter

    private var observers: [NSObjectProtocol] = []

    private struct WeakSubscriber {
        weak var subscriber: EmbeddedBlockAppPresenceSubscribing?
    }

    init(applicationState: @escaping () -> UIApplication.State = { UIApplication.shared.applicationState },
         isSDKInitialized: @escaping () -> Bool = { SessionTemporaryStorage.shared.isInitializationCalled },
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() },
         notificationCenter: NotificationCenter = .default) {
        self.applicationState = applicationState
        self.isSDKInitialized = isSDKInitialized
        self.now = now
        self.notificationCenter = notificationCenter

        observe(UIApplication.didEnterBackgroundNotification) { presence, _ in
            presence.hasBeenInBackground = true
            presence.notify { $0.appDidEnterBackground() }
        }
        observe(UIApplication.willEnterForegroundNotification) { presence, _ in
            presence.returned()
        }
        observe(UIApplication.didBecomeActiveNotification) { presence, _ in
            presence.becamePresentIfSo()
            presence.announceTheReturnIfPresent()
        }
        observe(.inappSessionChecked) { presence, notification in
            let startedAt = notification.userInfo?[Constants.Notification.sessionCheckStartedAt] as? TimeInterval
            let startsNewSession = notification.userInfo?[Constants.Notification.startsNewSession] as? Bool == true
            presence.sessionChecked(startedAt: startedAt)
            presence.notify { $0.sessionChecked(startedAt: startedAt, startsNewSession: startsNewSession) }
            presence.announceTheReturnIfPresent()
        }
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
    }

    func subscribe(_ subscriber: EmbeddedBlockAppPresenceSubscribing) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self, weak subscriber] in
                guard let subscriber else { return }

                self?.subscribe(subscriber)
            }
            return
        }

        subscribers.removeAll { $0.subscriber == nil }
        subscribers.append(WeakSubscriber(subscriber: subscriber))
    }

    func answersTheReturn(checkStartedAt startedAt: TimeInterval?) -> Bool {
        guard let returnedAt else { return true }
        guard let startedAt else { return false }

        return startedAt >= returnedAt
    }

    func reset() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { reset() }
            return
        }

        returnedAt = nil
        hasBeenInBackground = false
        isReturnUnannounced = false
    }

    private func returned() {
        guard hasBeenInBackground, isSDKInitialized() else { return }

        returnedAt = now()
        isReturnUnannounced = true
    }

    private func sessionChecked(startedAt: TimeInterval?) {
        guard isAwaitingSessionCheck, answersTheReturn(checkStartedAt: startedAt) else { return }

        returnedAt = nil
        guard isPresent else {
            Logger.common(message: "[EmbeddedBlock] The return's session check ended while the app is not active — blocks waiting for it start, their shows wait for the app to be active",
                          category: .embeddedBlocks)
            notify { $0.sessionCheckEndedWhileNotActive() }
            return
        }

        notify { $0.userDidBecomePresent() }
    }

    private func becamePresentIfSo() {
        guard isPresent else { return }

        notify { $0.userDidBecomePresent() }
    }

    private func announceTheReturnIfPresent() {
        guard isReturnUnannounced, isPresent else { return }

        isReturnUnannounced = false
        notify { $0.userReturned() }
    }

    private func notify(_ event: (EmbeddedBlockAppPresenceSubscribing) -> Void) {
        subscribers.removeAll { $0.subscriber == nil }
        subscribers.compactMap(\.subscriber).forEach(event)
    }

    private func observe(_ name: Notification.Name, _ handle: @escaping (EmbeddedBlockAppPresence, Notification) -> Void) {
        observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }

            handle(self, notification)
        })
    }
}
