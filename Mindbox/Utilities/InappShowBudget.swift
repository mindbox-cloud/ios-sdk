//
//  InappShowBudget.swift
//  Mindbox
//
//  Created by Sergei Semko on 03.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

enum InappShowBudgetOwner: Hashable {
    case overlay
    case place(String)
}

struct InappShowReservation: Equatable {
    let inAppId: String
    let reservedAt: Date
}

/// The session's show budget as one value: what was shown and what is spoken for but not yet on
/// screen. Reset as one with the session.
struct InappShowBudgetState: Equatable {
    var shownInSession: [String] = []
    var reservations: [InappShowBudgetOwner: InappShowReservation] = [:]
}

protocol InappShowBudgeting: AnyObject {

    /// Checks the show budgets and takes a slot in them in one step, so nobody passes on the same count.
    /// Priority and `unlimited` in-apps pass without a slot. An owner reserving the same in-app again
    /// keeps its slot; another in-app replaces it, and a refused replacement leaves the owner with none.
    func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?) -> Bool

    /// The slot became a show: it leaves the reservations and, when the frequency counts shows, enters
    /// the session count, the history and the cooldown. Without a slot the show is still recorded.
    func commit(_ owner: InappShowBudgetOwner, inAppId: String, frequency: InappFrequency?)

    /// The slot is given back without a show.
    func release(_ owner: InappShowBudgetOwner)

    /// The moment `minIntervalBetweenShows` counts from — written when the frequency counts shows.
    func recordCooldown(frequency: InappFrequency?)
}

/// Every budget read and write goes through one `$showBudget.mutate`: the check and the slot it
/// takes must see the same counts, and a reset must not land between them.
final class InappShowBudget: InappShowBudgeting {

    private let persistenceStorage: PersistenceStorage
    private let trackingService: InAppTrackingServiceProtocol
    private let now: () -> Date

    init(persistenceStorage: PersistenceStorage,
         trackingService: InAppTrackingServiceProtocol,
         now: @escaping () -> Date = Date.init) {
        self.persistenceStorage = persistenceStorage
        self.trackingService = trackingService
        self.now = now
    }

    func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?) -> Bool {
        SessionTemporaryStorage.shared.$showBudget.mutate { state in
            if state.reservations[owner]?.inAppId == inAppId {
                return true
            }
            state.reservations.removeValue(forKey: owner)

            let frequencyValidator = InappFrequencyValidator(persistenceStorage: persistenceStorage)
            guard frequencyValidator.isValid(frequency: frequency, id: inAppId, shownInSession: state.shownInSession) else {
                return false
            }

            if isPriority || !InappFrequency.countsShows(frequency) {
                Logger.common(message: "[ShowBudget] \(isPriority ? "Priority" : "Unlimited") in-app \(inAppId) passes the show budgets without a slot",
                              level: .debug, category: .inAppMessages)
                return true
            }

            guard isUnderSessionLimit(state), isUnderDailyLimit(state), hasElapsedMinimumInterval(state) else {
                return false
            }

            state.reservations[owner] = InappShowReservation(inAppId: inAppId, reservedAt: now())
            return true
        }
    }

    func commit(_ owner: InappShowBudgetOwner, inAppId: String, frequency: InappFrequency?) {
        SessionTemporaryStorage.shared.$showBudget.mutate { state in
            state.reservations.removeValue(forKey: owner)

            guard InappFrequency.countsShows(frequency) else { return }

            state.shownInSession.append(inAppId)
            trackingService.trackInAppShown(id: inAppId)
            trackingService.saveInappStateChange()
        }
    }

    func release(_ owner: InappShowBudgetOwner) {
        SessionTemporaryStorage.shared.$showBudget.mutate { state in
            state.reservations.removeValue(forKey: owner)
        }
    }

    func recordCooldown(frequency: InappFrequency?) {
        guard InappFrequency.countsShows(frequency) else { return }

        SessionTemporaryStorage.shared.$showBudget.mutate { _ in
            trackingService.saveInappStateChange()
        }
    }

    // MARK: - The budget rules

    private func isUnderSessionLimit(_ state: InappShowBudgetState) -> Bool {
        guard let limit = positiveLimit(SessionTemporaryStorage.shared.inAppSettings?.maxInappsPerSession, named: "Session") else {
            return true
        }

        let isAllowed = limit > state.shownInSession.count + state.reservations.count
        Logger.common(message: "[ShowBudget] [Session] shown: \(state.shownInSession.count), reserved: \(state.reservations.count), limit: \(limit), allowed: \(isAllowed)",
                      level: .info, category: .inAppMessages)
        return isAllowed
    }

    private func isUnderDailyLimit(_ state: InappShowBudgetState) -> Bool {
        guard let limit = positiveLimit(SessionTemporaryStorage.shared.inAppSettings?.maxInappsPerDay, named: "Daily") else {
            return true
        }

        let shownToday = shownTodayCount()
        let isAllowed = limit > shownToday + state.reservations.count
        Logger.common(message: "[ShowBudget] [Daily] shown today: \(shownToday), reserved: \(state.reservations.count), limit: \(limit), allowed: \(isAllowed)",
                      level: .info, category: .inAppMessages)
        return isAllowed
    }

    private func hasElapsedMinimumInterval(_ state: InappShowBudgetState) -> Bool {
        guard let minIntervalString = SessionTemporaryStorage.shared.inAppSettings?.minIntervalBetweenShows,
              let minIntervalSeconds = try? minIntervalString.parseTimeSpanToSeconds(),
              minIntervalSeconds > 0 else {
            Logger.common(message: "[ShowBudget] [minInterval] minIntervalBetweenShows not set, invalid or not positive, skipping the interval",
                          level: .info, category: .inAppMessages)
            return true
        }

        let lastReservation = state.reservations.values.map(\.reservedAt).max()
        guard let lastChange = [persistenceStorage.lastInappStateChangeDate, lastReservation].compactMap({ $0 }).max() else {
            Logger.common(message: "[ShowBudget] [minInterval] nothing shown or reserved yet, allowing", level: .info, category: .inAppMessages)
            return true
        }

        let nextAllowedShowTime = lastChange.addingTimeInterval(TimeInterval(minIntervalSeconds))
        let isAllowed = nextAllowedShowTime < now()
        Logger.common(message: "[ShowBudget] [minInterval] last: \(lastChange.asDateTimeWithSeconds), next allowed: \(nextAllowedShowTime.asDateTimeWithSeconds), allowed: \(isAllowed)",
                      level: .info, category: .inAppMessages)
        return isAllowed
    }

    private func positiveLimit(_ limit: Int?, named name: String) -> Int? {
        guard let limit else {
            Logger.common(message: "[ShowBudget] [\(name)] No limit specified", level: .info, category: .inAppMessages)
            return nil
        }

        guard limit > 0 else {
            Logger.common(message: "[ShowBudget] [\(name)] Limit is not positive (\(limit)), treating as no limit", level: .info, category: .inAppMessages)
            return nil
        }

        return limit
    }

    private func shownTodayCount() -> Int {
        guard let dates = persistenceStorage.shownDatesByInApp, !dates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        return dates.values.reduce(0) { count, dates in
            count + dates.filter { calendar.isDate($0, inSameDayAs: today) }.count
        }
    }
}
