//
//  EmbeddedBlockWaitBudget.swift
//  Mindbox
//
//  Created by Sergei Semko on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import QuartzCore
import MindboxLogger

final class EmbeddedBlockWaitBudget {

    var isNeeded: () -> Bool = { false }

    /// Called on the main thread.
    var onExpire: () -> Void = {}

    var isRunning: Bool { workItem != nil }

    private let placeSystemName: String

    private let duration: () -> TimeInterval

    /// Monotonic, not `Date`: an NTP correction or a manual clock change would make a spent stretch
    /// negative and stretch the wait past its budget.
    private let now: () -> TimeInterval

    private let notificationCenter: NotificationCenter

    private let schedule: EmbeddedBlockWaitScheduling

    private var workItem: DispatchWorkItem?

    /// Foreground time the current attempt has waited so far.
    private(set) var consumed: TimeInterval = 0

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

    func armIfNeeded() {
        guard workItem == nil, isNeeded() else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }

            self.workItem = nil
            self.resumedAt = nil
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

    func pause() {
        guard let resumedAt else { return }

        consumed += max(0, now() - resumedAt)
        self.resumedAt = nil
        workItem?.cancel()
        workItem = nil
    }

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

typealias EmbeddedBlockWaitScheduling = (TimeInterval, DispatchWorkItem) -> Void
