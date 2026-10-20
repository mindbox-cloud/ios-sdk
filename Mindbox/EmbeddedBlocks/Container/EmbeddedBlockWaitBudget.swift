//
//  EmbeddedBlockWaitBudget.swift
//  Mindbox
//
//  Created by Sergei Semko on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import QuartzCore
import MindboxLogger

final class EmbeddedBlockWaitBudget: EmbeddedBlockAppPresenceSubscribing {

    var isNeeded: () -> Bool = { false }

    var onExpire: () -> Void = {}

    var isRunning: Bool { workItem != nil }

    private let placeSystemName: String

    private let duration: () -> TimeInterval

    private let now: () -> TimeInterval

    private let presence: EmbeddedBlockAppPresence

    private let schedule: EmbeddedBlockWaitScheduling

    private var workItem: DispatchWorkItem?

    private(set) var consumed: TimeInterval = 0

    private var resumedAt: TimeInterval?

    private var remaining: TimeInterval { max(0, duration() - consumed) }

    init(placeSystemName: String,
         duration: @escaping () -> TimeInterval,
         now: @escaping () -> TimeInterval = { CACurrentMediaTime() },
         presence: EmbeddedBlockAppPresence = .shared,
         schedule: @escaping EmbeddedBlockWaitScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.placeSystemName = placeSystemName
        self.duration = duration
        self.now = now
        self.presence = presence
        self.schedule = schedule

        presence.subscribe(self)
    }

    deinit {
        workItem?.cancel()
    }

    func armIfNeeded() {
        assert(Thread.isMainThread)
        guard workItem == nil, !presence.isInBackground, isNeeded() else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }

            self.workItem = nil
            self.resumedAt = nil
            self.consumed = self.duration()

            Logger.common(message: "[EmbeddedBlock] Block '\(self.placeSystemName)' timed out after \(self.duration())s of waiting",
                          category: .embeddedBlocks)
            self.onExpire()
        }

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

    func refresh() {
        if isNeeded() {
            armIfNeeded()
        } else {
            pause()
        }
    }

    func appDidEnterBackground() {
        guard isRunning else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' went to the background while loading, pausing the timeout",
                      category: .embeddedBlocks)
        pause()
    }

    func appWillEnterForeground() {
        armIfNeeded()
    }
}

typealias EmbeddedBlockWaitScheduling = (TimeInterval, DispatchWorkItem) -> Void
