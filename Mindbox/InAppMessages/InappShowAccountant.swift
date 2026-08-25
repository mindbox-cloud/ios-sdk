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

    /// `Inapp.Show` to the backend, then the local show history and the cooldown when the frequency counts shows.
    func recordShow(_ show: InappShow)

    /// The moment `minIntervalBetweenShows` counts from — written when the frequency counts shows.
    func recordCooldown(frequency: InappFrequency?)

    /// A block's show counts when its place shows a different in-app than it showed last: 1 → 2 → 1 in
    /// one session is three shows, the same in-app again — a rebuilt page, a rotation — is none.
    func recordBlockShow(_ show: InappShow, at place: String)
}

final class InappShowAccountant: InappShowAccounting {

    private let tracker: InAppMessagesTrackerProtocol
    private let trackingService: InAppTrackingServiceProtocol

    init(tracker: InAppMessagesTrackerProtocol, trackingService: InAppTrackingServiceProtocol) {
        self.tracker = tracker
        self.trackingService = trackingService
    }

    func recordShow(_ show: InappShow) {
        do {
            try tracker.trackView(id: show.inAppId, timeToDisplay: show.timeToDisplay.toTimeSpan(), tags: show.tags)
        } catch {
            Logger.common(message: "[InappShowAccountant] Inapp.Show for \(show.inAppId) was not queued: \(error)",
                          level: .error, category: .inAppMessages)
        }

        guard InappFrequency.countsShows(show.frequency) else { return }

        trackingService.trackInAppShown(id: show.inAppId)
        trackingService.saveInappStateChange()
    }

    func recordCooldown(frequency: InappFrequency?) {
        guard InappFrequency.countsShows(frequency) else { return }

        trackingService.saveInappStateChange()
    }

    func recordBlockShow(_ show: InappShow, at place: String) {
        guard SessionTemporaryStorage.shared.placeShownInappId[place] != show.inAppId else {
            Logger.common(message: "[InappShowAccountant] Place '\(place)' shows in-app \(show.inAppId) again — nothing new to account for",
                          level: .debug, category: .inAppMessages)
            return
        }

        SessionTemporaryStorage.shared.$placeShownInappId.mutate { $0[place] = show.inAppId }
        recordShow(show)
    }
}
