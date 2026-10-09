//
//  EmbeddedBlockAppPresence.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import QuartzCore

protocol EmbeddedBlockAppPresenceSubscribing: AnyObject {

    func appDidEnterBackground()

    /// The user sees the app again, in a session that is known.
    func userDidBecomePresent()
}

extension EmbeddedBlockAppPresenceSubscribing {

    func appDidEnterBackground() {}

    func userDidBecomePresent() {}
}

/// Whether the user sees the app, in a known session. One for the process, so a block created between a return and the end
/// of that return's session check waits like the rest. Main thread only.
final class EmbeddedBlockAppPresence {

    /// Created with the SDK, so that it has seen every return a block can be created after.
    static let shared = EmbeddedBlockAppPresence()

    /// `.inactive` is not seen yet. From a return until that activation's session check ends, what is due
    /// could still be accounted to the session that has just expired.
    var isPresent: Bool { applicationState() == .active && !isAwaitingSessionCheck }

    var isAwaitingSessionCheck: Bool { returnedAt != nil }

    /// On the clock the session check stamps itself with: a wall clock stepped back on wake would make
    /// the return's own check look older than the return.
    private var returnedAt: TimeInterval?

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
            presence.notify { $0.appDidEnterBackground() }
        }
        observe(UIApplication.willEnterForegroundNotification) { presence, _ in
            presence.returned()
        }
        observe(UIApplication.didBecomeActiveNotification) { presence, _ in
            presence.becamePresentIfSo()
        }
        observe(.inappSessionChecked) { presence, notification in
            presence.sessionChecked(startedAt: notification.userInfo?[Constants.Notification.sessionCheckStartedAt] as? TimeInterval)
        }
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
    }

    /// Callable from any thread, like the init of the block that subscribes; held weakly.
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

    /// The process-wide instance outlives a test: suites that reach it start from a known state.
    func reset() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { reset() }
            return
        }

        returnedAt = nil
    }

    /// No session check follows a return before initialization, and there is no session to end yet.
    private func returned() {
        guard isSDKInitialized() else { return }

        returnedAt = now()
    }

    /// Only a check that decided after the return answers for it: one still in flight from before the
    /// trip to the background says nothing about the session the user came back to.
    private func sessionChecked(startedAt: TimeInterval?) {
        guard let returnedAt, let startedAt, startedAt >= returnedAt else { return }

        self.returnedAt = nil
        becamePresentIfSo()
    }

    private func becamePresentIfSo() {
        guard isPresent else { return }

        notify { $0.userDidBecomePresent() }
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
