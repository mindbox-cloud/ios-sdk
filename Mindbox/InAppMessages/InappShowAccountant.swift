//
//  InappShowAccountant.swift
//  Mindbox
//
//  Created by Sergei Semko on 25.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// A show as the accounting sees it — the same for an overlay window and a block page.
struct InappShow {
    let inAppId: String
    let frequency: InappFrequency?
    let tags: [String: String]?
    let timeToDisplay: TimeInterval
}

protocol InappShowAccounting: AnyObject {

    func recordShow(_ show: InappShow)

    func recordCooldown(frequency: InappFrequency?)

    func recordBlockShow(_ show: InappShow, at place: String)
}

final class InappShowAccountant: InappShowAccounting {

    private let tracker: InAppMessagesTrackerProtocol
    private let budget: InappShowBudgeting

    init(tracker: InAppMessagesTrackerProtocol, budget: InappShowBudgeting) {
        self.tracker = tracker
        self.budget = budget
    }

    func recordShow(_ show: InappShow) {
        record(show, owner: .overlay(show.inAppId))
    }

    func recordCooldown(frequency: InappFrequency?) {
        budget.recordCooldown(frequency: frequency)
    }

    func recordBlockShow(_ show: InappShow, at place: String) {
        guard SessionTemporaryStorage.shared.$ledger.mutate({ $0.recordShow(show.inAppId, at: place) }) else {
            Logger.common(message: "[InappShowAccountant] Place '\(place)' shows in-app \(show.inAppId) again — nothing new to account for",
                          level: .debug, category: .inAppMessages)
            budget.release(.place(place))
            return
        }

        record(show, owner: .place(place))
    }

    private func record(_ show: InappShow, owner: InappShowBudgetOwner) {
        do {
            try tracker.trackView(id: show.inAppId, timeToDisplay: show.timeToDisplay.toTimeSpan(), tags: show.tags)
        } catch {
            Logger.common(message: "[InappShowAccountant] Inapp.Show for \(show.inAppId) was not queued: \(error)",
                          level: .error, category: .inAppMessages)
        }

        budget.commit(owner, inAppId: show.inAppId, frequency: show.frequency)
    }
}
