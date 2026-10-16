//
//  InappShowBudget.swift
//  Mindbox
//
//  Created by Sergei Semko on 03.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// An overlay is keyed by its own in-app, so a show on request cannot touch a scheduled overlay's slot;
/// a place holds one slot for whatever it shows next.
enum InappShowBudgetOwner: Hashable {
    case overlay(String)
    case place(String)
}

struct InappShowReservation: Equatable {
    let inAppId: String
    let reservedAt: Date
}

enum InappShowReservationOutcome: Equatable {
    case granted
    case notNeeded
    case refused
}

struct InappShowBudgetState: Equatable {
    var shownInSession: [String] = []
    var reservations: [InappShowBudgetOwner: InappShowReservation] = [:]
}

struct InappShowHistory: Equatable {
    var shownDatesByInApp: [String: [Date]]?
    var lastStateChangeDate: Date?
}

struct InappUnsavedShowHistory: Equatable {
    var history: InappShowHistory
    var revision = 0
    var isBeingSaved = false
}

protocol InappShowBudgeting: AnyObject {

    func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?, inSession sessionEpoch: Int?) -> InappShowReservationOutcome?

    func commit(_ owner: InappShowBudgetOwner, inAppId: String, frequency: InappFrequency?, inSession sessionEpoch: Int?, to ledger: inout InappSessionLedger)

    func release(_ owner: InappShowBudgetOwner, inSession sessionEpoch: Int?, from ledger: inout InappSessionLedger)

    /// The moment `minIntervalBetweenShows` counts from — written when the frequency counts shows.
    func recordCooldown(frequency: InappFrequency?)

    func saveShowHistory()
}

extension InappShowBudgeting {

    func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?) -> InappShowReservationOutcome {
        reserve(owner, inAppId: inAppId, isPriority: isPriority, frequency: frequency, inSession: nil) ?? .refused
    }

    func commit(_ owner: InappShowBudgetOwner, inAppId: String, frequency: InappFrequency?, inSession sessionEpoch: Int? = nil) {
        SessionTemporaryStorage.shared.$ledger.mutate { commit(owner, inAppId: inAppId, frequency: frequency, inSession: sessionEpoch, to: &$0) }
        saveShowHistory()
    }

    func release(_ owner: InappShowBudgetOwner, inSession sessionEpoch: Int? = nil) {
        SessionTemporaryStorage.shared.$ledger.mutate { release(owner, inSession: sessionEpoch, from: &$0) }
    }
}

/// Every budget read and write goes through one `$ledger.mutate`: the check and the slot it
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

    func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?, inSession sessionEpoch: Int?) -> InappShowReservationOutcome? {
        SessionTemporaryStorage.shared.$ledger.withinLiveSession(sessionEpoch) { ledger in
            reserve(owner, inAppId: inAppId, isPriority: isPriority, frequency: frequency, in: &ledger)
        }
    }

    func commit(_ owner: InappShowBudgetOwner, inAppId: String, frequency: InappFrequency?, inSession sessionEpoch: Int?, to ledger: inout InappSessionLedger) {
        let isOfThisSession = ledger.budgetCounts(sessionEpoch)
        if !isOfThisSession {
            Logger.common(message: "[ShowBudget] The show of \(inAppId) belongs to a session that has ended — only the frequency history records it",
                          level: .debug, category: .inAppMessages)
        } else if let held = ledger.showBudget.reservations[owner], held.inAppId != inAppId {
            Logger.common(message: "[ShowBudget] \(owner) now holds a slot for in-app \(held.inAppId), the show of \(inAppId) leaves it in place",
                          level: .debug, category: .inAppMessages)
        } else {
            ledger.showBudget.reservations.removeValue(forKey: owner)
        }

        guard InappFrequency.countsShows(frequency) else { return }

        if isOfThisSession {
            ledger.showBudget.shownInSession.append(inAppId)
        }
        ledger.changeShowHistory(persisted: persistedShowHistory) { history in
            trackingService.trackInAppShown(id: inAppId, in: &history)
            trackingService.saveInappStateChange(in: &history)
        }
    }

    func release(_ owner: InappShowBudgetOwner, inSession sessionEpoch: Int?, from ledger: inout InappSessionLedger) {
        guard ledger.budgetCounts(sessionEpoch) else { return }

        ledger.showBudget.reservations.removeValue(forKey: owner)
    }

    func recordCooldown(frequency: InappFrequency?) {
        guard InappFrequency.countsShows(frequency) else { return }

        SessionTemporaryStorage.shared.$ledger.mutate { ledger in
            ledger.changeShowHistory(persisted: persistedShowHistory) { trackingService.saveInappStateChange(in: &$0) }
        }
        saveShowHistory()
    }

    func saveShowHistory() {
        var next = SessionTemporaryStorage.shared.$ledger.mutate { $0.takeShowHistoryToSave() }
        while let unsaved = next {
            save(unsaved.history)
            next = SessionTemporaryStorage.shared.$ledger.mutate { $0.showHistorySaved(unsaved) }
        }
    }

    private func save(_ history: InappShowHistory) {
        if persistenceStorage.shownDatesByInApp != history.shownDatesByInApp {
            persistenceStorage.shownDatesByInApp = history.shownDatesByInApp
        }
        if persistenceStorage.lastInappStateChangeDate != history.lastStateChangeDate {
            persistenceStorage.lastInappStateChangeDate = history.lastStateChangeDate
        }
    }

    private func persistedShowHistory() -> InappShowHistory {
        InappShowHistory(shownDatesByInApp: persistenceStorage.shownDatesByInApp, lastStateChangeDate: persistenceStorage.lastInappStateChangeDate)
    }

    private func reserve(_ owner: InappShowBudgetOwner, inAppId: String, isPriority: Bool, frequency: InappFrequency?, in ledger: inout InappSessionLedger) -> InappShowReservationOutcome {
        if ledger.showBudget.reservations[owner]?.inAppId == inAppId {
            return .notNeeded
        }
        ledger.showBudget.reservations.removeValue(forKey: owner)

        let history = ledger.unsavedShowHistory?.history ?? persistedShowHistory()
        let frequencyValidator = InappFrequencyValidator(persistenceStorage: persistenceStorage)
        guard frequencyValidator.isValid(frequency: frequency, id: inAppId, shownInSession: ledger.showBudget.shownInSession, shownDatesByInApp: history.shownDatesByInApp) else {
            return .refused
        }

        if isPriority || !InappFrequency.countsShows(frequency) {
            Logger.common(message: "[ShowBudget] \(isPriority ? "Priority" : "Unlimited") in-app \(inAppId) passes the show budgets without a slot",
                          level: .debug, category: .inAppMessages)
            return .notNeeded
        }

        guard isUnderSessionLimit(ledger.showBudget), isUnderDailyLimit(ledger.showBudget, history), hasElapsedMinimumInterval(ledger.showBudget, history) else {
            return .refused
        }

        ledger.showBudget.reservations[owner] = InappShowReservation(inAppId: inAppId, reservedAt: now())
        return .granted
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

    private func isUnderDailyLimit(_ state: InappShowBudgetState, _ history: InappShowHistory) -> Bool {
        guard let limit = positiveLimit(SessionTemporaryStorage.shared.inAppSettings?.maxInappsPerDay, named: "Daily") else {
            return true
        }

        let shownToday = shownTodayCount(history)
        let isAllowed = limit > shownToday + state.reservations.count
        Logger.common(message: "[ShowBudget] [Daily] shown today: \(shownToday), reserved: \(state.reservations.count), limit: \(limit), allowed: \(isAllowed)",
                      level: .info, category: .inAppMessages)
        return isAllowed
    }

    private func hasElapsedMinimumInterval(_ state: InappShowBudgetState, _ history: InappShowHistory) -> Bool {
        guard let minIntervalString = SessionTemporaryStorage.shared.inAppSettings?.minIntervalBetweenShows,
              let minIntervalMillis = try? minIntervalString.parseTimeSpanToMillis(),
              minIntervalMillis > 0 else {
            Logger.common(message: "[ShowBudget] [minInterval] minIntervalBetweenShows not set, invalid or not positive, skipping the interval",
                          level: .info, category: .inAppMessages)
            return true
        }

        let lastReservation = state.reservations.values.map(\.reservedAt).max()
        guard let lastChange = [history.lastStateChangeDate, lastReservation].compactMap({ $0 }).max() else {
            Logger.common(message: "[ShowBudget] [minInterval] nothing shown or reserved yet, allowing", level: .info, category: .inAppMessages)
            return true
        }

        let nextAllowedShowTime = lastChange.addingTimeInterval(TimeInterval(minIntervalMillis) / 1000)
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

    private func shownTodayCount(_ history: InappShowHistory) -> Int {
        guard let dates = history.shownDatesByInApp, !dates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        return dates.values.reduce(0) { count, dates in
            count + dates.filter { calendar.isDate($0, inSameDayAs: today) }.count
        }
    }
}

private extension InappSessionLedger {

    func budgetCounts(_ sessionEpoch: Int?) -> Bool {
        sessionEpoch.map { $0 == self.sessionEpoch } ?? true
    }
}
