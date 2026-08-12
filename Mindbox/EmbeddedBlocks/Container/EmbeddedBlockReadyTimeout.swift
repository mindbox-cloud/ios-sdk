//
//  EmbeddedBlockReadyTimeout.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import QuartzCore
import MindboxLogger

/// How long a block is given to show up — and the accounting of that time.
///
/// The budget belongs to the container, not to the content: whatever the block turns out to be,
/// the host layout does not wait for it forever. A block that misses the budget is collapsed by
/// the container.
///
/// What is counted is the user's waiting time, not calendar time: while nobody is waiting for the
/// block — the app is in the background, the container is out of the window — the count stands
/// still. Otherwise the user would come back to a block that gave up while nobody was looking.
///
/// Stands still, but does not start over: what was spent is remembered, and the attempt continues
/// its budget from where it was interrupted. A pause that handed the full budget back would never
/// end — a user switching between apps every five seconds would extend the wait indefinitely, and
/// the host layout would wait forever. Exactly what the budget exists to prevent. Only a new
/// attempt — `reset()` — gets the full budget again.
///
/// Loading is not affected by the pause: it runs its own course; in the background the system
/// throttles it, not the SDK.

/// Runs the work when the given remainder of the budget expires.
typealias EmbeddedBlockTimeoutScheduling = (TimeInterval, DispatchWorkItem) -> Void

final class EmbeddedBlockReadyTimeout {

    /// Whether the count is needed right now: the outcome is still unknown and the block is
    /// visible. Asked again on every arm, because both may have changed while paused.
    var isNeeded: () -> Bool = { false }

    /// Time is up. Called on the main thread.
    var onExpire: () -> Void = {}

    var isRunning: Bool { workItem != nil }

    private let blockId: String
    private let duration: TimeInterval

    /// The clock is its own seam: spent time cannot be counted without it, and tests cannot wait
    /// out the budget for real — they need a way to say that time has passed. The clock is
    /// monotonic, not `Date`: an NTP correction or a manual clock change would make the spent
    /// delta negative and stretch the wait past the budget.
    private let now: () -> TimeInterval

    /// Notifications are their own seam for the same reason as the clock: going to the background
    /// cannot be tested on the global center — a test notification would reach the blocks of tests
    /// running next to it.
    private let notificationCenter: NotificationCenter

    /// The scheduler is the same kind of seam for the same reason: a hard-wired queue would force
    /// budget tests to wait it out in real time — sleeping on every check and flaking on a busy
    /// machine.
    private let schedule: EmbeddedBlockTimeoutScheduling

    private var workItem: DispatchWorkItem?

    /// How much of the budget past waiting stretches have consumed.
    private var consumed: TimeInterval = 0

    /// When the current stretch started. `nil` — the count is not running.
    private var resumedAt: TimeInterval?

    private var remaining: TimeInterval { max(0, duration - consumed) }

    init(blockId: String,
         duration: TimeInterval,
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() },
         notificationCenter: NotificationCenter = .default,
         schedule: @escaping EmbeddedBlockTimeoutScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.blockId = blockId
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
            self.consumed = self.duration

            Logger.common(message: "[EmbeddedBlock] Block '\(self.blockId)' timed out after \(self.duration)s of waiting",
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

        Logger.common(message: "[EmbeddedBlock] Block '\(blockId)' went to the background while loading, pausing the timeout",
                      category: .embeddedBlocks)
        pause()
    }

    @objc
    private func applicationWillEnterForeground() {
        armIfNeeded()
    }
}
