//
//  EmbeddedBlockAckBudget.swift
//  Mindbox
//
//  Created by Sergei Semko on 31.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// The page's budget to confirm a data push. Spent only while somebody is looking at the block:
/// a pause suspends the spend, a return arms the remainder.
struct EmbeddedBlockAckBudget {

    private let now: () -> TimeInterval

    private var consumed: TimeInterval = 0

    private var resumedAt: TimeInterval?

    init(now: @escaping () -> TimeInterval) {
        self.now = now
    }

    var remaining: TimeInterval {
        max(0, TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds) - consumed)
    }

    mutating func resume() {
        resumedAt = now()
    }

    mutating func suspend() {
        if let resumedAt {
            consumed += max(0, now() - resumedAt)
            self.resumedAt = nil
        }
    }

    mutating func exhaust() {
        consumed = TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
        resumedAt = nil
    }

    mutating func reset() {
        consumed = 0
        resumedAt = nil
    }
}
