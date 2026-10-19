//
//  InappSessionLedger.swift
//  Mindbox
//
//  Created by Sergei Semko on 26.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct PageOffer: Hashable {
    let requesterInappId: String
    let inappId: String
}

struct ServedPlaceDelay: Hashable {
    let place: String
    let inappId: String
}

struct ReportedFailure: Hashable {
    let inappId: String
    let reason: String
}

enum BlockShowRecord: Equatable {
    case new
    case repeated
    case stale
}

struct InappSessionLedger: Equatable {

    var sessionEpoch = 0

    var vouchedInappIds: Set<String> = []

    var placeTargetedInappId: [String: String] = [:]

    var vouchedPageOffers: Set<PageOffer> = []

    var placesReportedUnanswered: Set<String> = []

    var servedPlaceDelays: Set<ServedPlaceDelay> = []

    var placeShownInappId: [String: String] = [:]

    var reportedFailures: Set<ReportedFailure> = []

    var showBudget = InappShowBudgetState()

    var isSessionEnding = false

    var unsavedShowHistory: InappUnsavedShowHistory?

    func hasEnded(_ sessionEpoch: Int) -> Bool {
        sessionEpoch != self.sessionEpoch || isSessionEnding
    }
}

// Each ask-and-record runs inside one $ledger.mutate, so a check cannot straddle a session reset.
extension InappSessionLedger {

    mutating func vouchWinner(_ inappId: String, at place: String) -> Bool {
        guard placeTargetedInappId[place] != inappId else { return false }

        placeTargetedInappId[place] = inappId
        vouchedInappIds.insert(inappId)
        return true
    }

    mutating func vouch(_ inappId: String) -> Bool {
        vouchedInappIds.insert(inappId).inserted
    }

    mutating func vouchOffer(_ offer: PageOffer) -> Bool {
        vouchedPageOffers.insert(offer).inserted
    }

    mutating func recordShow(_ inappId: String, at place: String, sessionEpoch: Int) -> BlockShowRecord {
        guard !hasEnded(sessionEpoch) else { return .stale }
        guard placeShownInappId[place] != inappId else { return .repeated }

        placeShownInappId[place] = inappId
        return .new
    }

    mutating func recordUnanswered(_ place: String) -> Bool {
        placesReportedUnanswered.insert(place).inserted
    }

    mutating func recordFailure(_ inappId: String, reason: String) -> Bool {
        reportedFailures.insert(ReportedFailure(inappId: inappId, reason: reason)).inserted
    }

    mutating func changeShowHistory(persisted: () -> InappShowHistory, _ change: (inout InappShowHistory) -> Void) {
        var unsaved = unsavedShowHistory ?? InappUnsavedShowHistory(history: persisted())
        change(&unsaved.history)
        unsaved.revision += 1
        unsavedShowHistory = unsaved
    }

    mutating func takeShowHistoryToSave() -> InappUnsavedShowHistory? {
        guard let unsaved = unsavedShowHistory, !unsaved.isBeingSaved else { return nil }

        unsavedShowHistory?.isBeingSaved = true
        return unsaved
    }

    mutating func showHistorySaved(_ saved: InappUnsavedShowHistory) -> InappUnsavedShowHistory? {
        guard let unsaved = unsavedShowHistory, unsaved.revision != saved.revision else {
            unsavedShowHistory = nil
            return nil
        }

        return unsaved
    }
}

extension Locked where Value == InappSessionLedger {

    func withinLiveSession<Result>(_ sessionEpoch: Int?, _ body: (inout InappSessionLedger) -> Result) -> Result? {
        mutate { ledger in
            if let sessionEpoch, ledger.hasEnded(sessionEpoch) {
                return nil
            }

            return body(&ledger)
        }
    }
}
