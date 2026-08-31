//
//  InappSessionLedger.swift
//  Mindbox
//
//  Created by Sergei Semko on 26.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// One in-app a block's page was allowed to draw — what `Inapp.Targeting` for a page's question is
/// deduplicated by: once per session, per block and in-app.
struct BlockOffer: Hashable {
    let blockInappId: String
    let inappId: String
}

/// A `delayTime` that ran out for an in-app at a place: a block coming back to the screen gets that
/// content at once instead of waiting again.
struct ServedPlaceDelay: Hashable {
    let place: String
    let inappId: String
}

/// What this session already told the funnel and served to places, kept so nothing is repeated.
/// Reset as one with the session.
struct InappSessionLedger: Equatable {

    /// In-apps vouched for once per session — the losers at a place.
    var vouchedInappIds: Set<String> = []

    /// The in-app each place last vouched for as its winner: its `Inapp.Targeting` pairs with the show,
    /// so it goes out again when the place changes what it shows and then changes back.
    var placeTargetedInappId: [String: String] = [:]

    var vouchedBlockOffers: Set<BlockOffer> = []

    /// Places whose block already reported that the SDK never answered — once per place per session.
    var placesReportedUnanswered: Set<String> = []

    var servedPlaceDelays: Set<ServedPlaceDelay> = []

    /// The in-app each place showed last — a block's show is accounted when this changes.
    var placeShownInappId: [String: String] = [:]
}
