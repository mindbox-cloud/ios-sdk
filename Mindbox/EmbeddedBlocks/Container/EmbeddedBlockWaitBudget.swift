//
//  EmbeddedBlockWaitBudget.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import QuartzCore
import MindboxLogger

/// How long a block is given to show up, and the accounting of that time.
///
/// What is counted is the user's waiting time, not calendar time: while nobody is waiting for the
/// block — the app is in the background, the container is out of the window — the count stands still.
/// It stands still without starting over, because a pause that handed the full budget back would never
/// end: a user switching apps every few seconds would stretch the wait indefinitely. Only a new
/// attempt (`reset()`) gets the whole budget again.
///
/// The pause does not reach loading. That runs its own course, throttled by the system rather than by
/// the SDK.
final class EmbeddedBlockWaitBudget {

    /// Whether the count is needed right now: the outcome is still unknown and the block is
    /// visible. Asked again on every arm, because both may have changed while paused.
    var isNeeded: () -> Bool = { false }

    /// Time is up. Called on the main thread.
    var onExpire: () -> Void = {}

    var isRunning: Bool { workItem != nil }

    private let placeSystemName: String

    /// Asked when the count is armed rather than stored: the block waits first for an answer about what
    /// to show and then for the page to report itself, and the two waits have different budgets.
    private let duration: () -> TimeInterval

    /// Monotonic, not `Date`: an NTP correction or a manual clock change would make a spent stretch
    /// negative and stretch the wait past its budget.
    private let now: () -> TimeInterval

    /// Its own center, so a test's background notification cannot reach the budgets of the tests
    /// running next to it.
    private let notificationCenter: NotificationCenter

    /// Injected so the budget can be tested without waiting it out in real time.
    private let schedule: EmbeddedBlockWaitScheduling

    private var workItem: DispatchWorkItem?

    /// How much of the budget past waiting stretches have consumed.
    private var consumed: TimeInterval = 0

    /// When the current stretch started. `nil` — the count is not running.
    private var resumedAt: TimeInterval?

    private var remaining: TimeInterval { max(0, duration() - consumed) }

    init(placeSystemName: String,
         duration: @escaping () -> TimeInterval,
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() },
         notificationCenter: NotificationCenter = .default,
         schedule: @escaping EmbeddedBlockWaitScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.placeSystemName = placeSystemName
        self.duration = duration
        self.now = now
        self.notificationCenter = notificationCenter
        self.schedule = schedule

        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidEnterBackground),
                                       name: UIApplication.didEnterBackgroundNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground),
                                       name: UIApplication.willEnterForegroundNotification,
                                       object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
        workItem?.cancel()
    }

    /// Arms the count for the remainder of the budget, if it is needed and not already running.
    /// Call as often as convenient: extra calls do nothing, so entering the window, returning from
    /// the background, and reloading all share the same call.
    func armIfNeeded() {
        guard workItem == nil, isNeeded() else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }

            self.workItem = nil
            self.resumedAt = nil
            // The budget is spent in full: if the block is somehow armed again, there is nothing
            // left to wait for.
            self.consumed = self.duration()

            Logger.common(message: "[EmbeddedBlock] Block '\(self.placeSystemName)' timed out after \(self.duration())s of waiting",
                          category: .embeddedBlocks)
            self.onExpire()
        }

        // The work is stored in the property before it is scheduled: the scheduler is free to run
        // it right away, and it must find the budget in a consistent state.
        resumedAt = now()
        workItem = work
        schedule(remaining, work)
    }

    /// Stops the count, remembering what was spent. The attempt is not cancelled: `armIfNeeded()`
    /// continues it from the remainder.
    func pause() {
        guard let resumedAt else { return }

        consumed += max(0, now() - resumedAt)
        self.resumedAt = nil
        workItem?.cancel()
        workItem = nil
    }

    /// Stops the count and restores the full budget: the previous attempt is over — with an
    /// outcome, or because the next one started — and its remainder has nothing to do with the
    /// new one.
    func reset() {
        pause()
        consumed = 0
    }

    @objc
    private func applicationDidEnterBackground() {
        guard isRunning else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' went to the background while loading, pausing the timeout",
                      category: .embeddedBlocks)
        pause()
    }

    @objc
    private func applicationWillEnterForeground() {
        armIfNeeded()
    }
}

/// Runs the work when the given remainder of the budget expires.
typealias EmbeddedBlockWaitScheduling = (TimeInterval, DispatchWorkItem) -> Void
