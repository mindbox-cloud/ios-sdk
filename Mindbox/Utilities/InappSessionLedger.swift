//
//  InappSessionLedger.swift
//  Mindbox
//
//  Created by Sergei Semko on 26.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// One in-app a page was allowed to draw — what `Inapp.Targeting` for a page's question is
/// deduplicated by: once per session, per requesting in-app and in-app.
struct PageOffer: Hashable {
    let requesterInappId: String
    let inappId: String
}

/// A `delayTime` that ran out for an in-app at a place: a block coming back to the screen gets that
/// content at once instead of waiting again.
struct ServedPlaceDelay: Hashable {
    let place: String
    let inappId: String
}

/// The once-per-session key of `Inapp.ShowFailure`, shared with Android.
struct ReportedFailure: Hashable {
    let inappId: String
    let reason: String
}

/// How a block's show stands against what the session already accounted.
enum BlockShowRecord: Equatable {
    case new
    case repeated
    /// Of a session that has ended or is ending: it accounts nothing in the current one.
    case stale
}

/// What this session already told the funnel and served to places, kept so nothing is repeated.
/// Reset as one with the session.
struct InappSessionLedger: Equatable {

    /// Which session this is: grows by one with every reset, so an answer computed before a reset
    /// can be told from one computed after it.
    var sessionEpoch = 0

    /// In-apps vouched for once per session — the losers at a place.
    var vouchedInappIds: Set<String> = []

    /// The in-app each place last vouched for as its winner: its `Inapp.Targeting` pairs with the show,
    /// so it goes out again when the place changes what it shows and then changes back.
    var placeTargetedInappId: [String: String] = [:]

    var vouchedPageOffers: Set<PageOffer> = []

    /// Places whose block already reported that the SDK never answered — once per place per session.
    var placesReportedUnanswered: Set<String> = []

    var servedPlaceDelays: Set<ServedPlaceDelay> = []

    /// The in-app each place showed last — a block's show is accounted when this changes.
    var placeShownInappId: [String: String] = [:]

    var reportedFailures: Set<ReportedFailure> = []

    /// Set by the session check that found this session expired, in the hold that read the last visit; the reset
    /// that follows replaces the ledger and with it the mark.
    var isSessionEnding = false

    /// What an answer, a show or a report computed in `sessionEpoch` is judged by: that session is over, or is
    /// being ended by a session check that has decided so.
    func hasEnded(_ sessionEpoch: Int) -> Bool {
        sessionEpoch < self.sessionEpoch || isSessionEnding
    }
}

// Ask-and-record in one step, each meant to run inside a single `$ledger.mutate`: callers live on
// different queues, and a check split from its write can straddle the session reset.
extension InappSessionLedger {

    /// True when the place's slot moves to this in-app; the winner is vouched for along the way.
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

    /// `new` when the place shows something other than what it showed last in this session.
    mutating func recordShow(_ inappId: String, at place: String, sessionEpoch: Int) -> BlockShowRecord {
        guard sessionEpoch == self.sessionEpoch, !hasEnded(sessionEpoch) else { return .stale }
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
}
