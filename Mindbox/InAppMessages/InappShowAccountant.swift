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

    /// Accounts a block's show in the session its answer was computed in: one of a session that has ended or is ending sends
    /// no `Inapp.Show` and writes nothing. The same in-app shown again at the place gives its slot back.
    func recordBlockShow(_ show: InappShow, at place: String, sessionEpoch: Int)
}

final class InappShowAccountant: InappShowAccounting {

    private let tracker: InAppMessagesTrackerProtocol
    private let budget: InappShowBudgeting

    init(tracker: InAppMessagesTrackerProtocol, budget: InappShowBudgeting) {
        self.tracker = tracker
        self.budget = budget
    }

    func recordShow(_ show: InappShow) {
        track(show)
        budget.commit(.overlay(show.inAppId), inAppId: show.inAppId, frequency: show.frequency)
    }

    func recordCooldown(frequency: InappFrequency?) {
        budget.recordCooldown(frequency: frequency)
    }

    func recordBlockShow(_ show: InappShow, at place: String, sessionEpoch: Int) {
        let owner = InappShowBudgetOwner.place(place)
        switch SessionTemporaryStorage.shared.$ledger.mutate({ $0.recordShow(show.inAppId, at: place, sessionEpoch: sessionEpoch) }) {
        case .new:
            budget.commit(owner, inAppId: show.inAppId, frequency: show.frequency, inSession: sessionEpoch)
            track(show)
        case .repeated:
            Logger.common(message: "[InappShowAccountant] Place '\(place)' shows in-app \(show.inAppId) again — nothing new to account for",
                          level: .debug, category: .inAppMessages)
            budget.release(owner, inSession: sessionEpoch)
        case .stale:
            Logger.common(message: "[InappShowAccountant] Place '\(place)' shows in-app \(show.inAppId) from an earlier session's answer — this session accounts it when the place confirms it",
                          level: .debug, category: .inAppMessages)
        }
    }

    private func track(_ show: InappShow) {
        do {
            try tracker.trackView(id: show.inAppId, timeToDisplay: show.timeToDisplay.toTimeSpan(), tags: show.tags)
        } catch {
            Logger.common(message: "[InappShowAccountant] Inapp.Show for \(show.inAppId) was not queued: \(error)",
                          level: .error, category: .inAppMessages)
        }
    }
}
