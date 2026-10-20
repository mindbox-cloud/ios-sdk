//
//  EmbeddedBlockDataPushWait.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class EmbeddedBlockDataPushWait: EmbeddedBlockAppPresenceSubscribing {

    private let placeSystemName: String

    private let schedule: EmbeddedBlockWaitScheduling

    private let presence: EmbeddedBlockAppPresence

    private var budget: EmbeddedBlockAckBudget

    private var timer: DispatchWorkItem?

    private var onTimeout: (() -> Void)?

    var isAwaitingConfirmation: Bool { onTimeout != nil }

    init(placeSystemName: String,
         now: @escaping () -> TimeInterval,
         schedule: @escaping EmbeddedBlockWaitScheduling,
         presence: EmbeddedBlockAppPresence) {
        self.placeSystemName = placeSystemName
        self.budget = EmbeddedBlockAckBudget(now: now)
        self.schedule = schedule
        self.presence = presence

        presence.subscribe(self)
    }

    func appDidEnterBackground() {
        suspend()
    }

    func arm(onTimeout: @escaping () -> Void) {
        cancel()

        self.onTimeout = onTimeout
        resume()
    }

    func resumeIfSuspended() {
        guard onTimeout != nil, timer == nil, presence.isPresent else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': a data push is still unconfirmed — waiting out the remaining \(budget.remaining)s",
                      category: .embeddedBlocks)
        resume()
    }

    func acknowledge() {
        guard onTimeout != nil else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page confirmed a data push nobody was waiting on",
                          level: .debug, category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the page took the new data — waiting for contentRendered",
                      category: .embeddedBlocks)
        cancel()
    }

    func suspend() {
        budget.suspend()
        timer?.cancel()
        timer = nil
    }

    func cancel() {
        suspend()
        budget.reset()
        onTimeout = nil
    }

    private func resume() {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }

            let onTimeout = self.onTimeout
            self.timer = nil
            self.budget.exhaust()
            self.onTimeout = nil
            onTimeout?()
        }

        budget.resume()
        timer = work
        schedule(budget.remaining, work)
    }
}
