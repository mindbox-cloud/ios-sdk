//
//  InappSessionLedgerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 01.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("In-app session ledger", .tags(.inappSelection))
struct InappSessionLedgerTests {

    @Test("A winner takes the place's slot once, until another takes it over")
    func winnerTakesTheSlotOnce() {
        var ledger = InappSessionLedger()

        let taken = ledger.vouchWinner("inapp-1", at: "place")
        let held = ledger.vouchWinner("inapp-1", at: "place")
        let moved = ledger.vouchWinner("inapp-2", at: "place")
        let returned = ledger.vouchWinner("inapp-1", at: "place")

        #expect(taken)
        #expect(!held)
        #expect(moved)
        #expect(returned)
    }

    @Test("A winner is vouched for along with its slot")
    func winnerIsVouchedForAlongWithItsSlot() {
        var ledger = InappSessionLedger()

        let taken = ledger.vouchWinner("inapp-1", at: "place")
        let vouchedAgain = ledger.vouch("inapp-1")

        #expect(taken)
        #expect(!vouchedAgain)
    }

    @Test("An in-app is vouched for once per session")
    func vouchIsOncePerSession() {
        var ledger = InappSessionLedger()

        let first = ledger.vouch("inapp-1")
        let second = ledger.vouch("inapp-1")
        let another = ledger.vouch("inapp-2")

        #expect(first)
        #expect(!second)
        #expect(another)
    }

    @Test("The same in-app offered by another block is a new offer")
    func offersAreOncePerBlockAndInapp() {
        var ledger = InappSessionLedger()

        let offered = ledger.vouchOffer(PageOffer(requesterInappId: "block-1", inappId: "inapp-1"))
        let repeated = ledger.vouchOffer(PageOffer(requesterInappId: "block-1", inappId: "inapp-1"))
        let otherBlock = ledger.vouchOffer(PageOffer(requesterInappId: "block-2", inappId: "inapp-1"))

        #expect(offered)
        #expect(!repeated)
        #expect(otherBlock)
    }

    @Test("A show is recorded when the place shows something new, places independent")
    func showsAreRecordedPerPlaceChange() {
        var ledger = InappSessionLedger()

        let shown = ledger.recordShow("inapp-1", at: "place", sessionEpoch: 0)
        let held = ledger.recordShow("inapp-1", at: "place", sessionEpoch: 0)
        let changed = ledger.recordShow("inapp-2", at: "place", sessionEpoch: 0)
        let returned = ledger.recordShow("inapp-1", at: "place", sessionEpoch: 0)
        let otherPlace = ledger.recordShow("inapp-1", at: "other-place", sessionEpoch: 0)

        #expect(shown == .new)
        #expect(held == .repeated)
        #expect(changed == .new)
        #expect(returned == .new)
        #expect(otherPlace == .new)
    }

    @Test("A show computed in an earlier session is refused and records nothing")
    func showOfAnEarlierSessionIsStale() {
        var ledger = InappSessionLedger(sessionEpoch: 3)

        let stale = ledger.recordShow("inapp-1", at: "place", sessionEpoch: 2)
        let current = ledger.recordShow("inapp-1", at: "place", sessionEpoch: 3)

        #expect(stale == .stale)
        #expect(current == .new)
    }

    @Test("A show of the session a check is ending is refused and records nothing")
    func showOfAnEndingSessionIsStale() {
        var ledger = InappSessionLedger(sessionEpoch: 3)
        ledger.isSessionEnding = true

        let ending = ledger.recordShow("inapp-1", at: "place", sessionEpoch: 3)

        #expect(ending == .stale)
        #expect(ledger.placeShownInappId.isEmpty)
    }

    @Test("A session has ended once a later one began, and is ending while a check ends it", arguments: [false, true])
    func sessionEndsWithTheResetOrTheCheckEndingIt(isEnding: Bool) {
        var ledger = InappSessionLedger(sessionEpoch: 3)
        ledger.isSessionEnding = isEnding

        #expect(ledger.hasEnded(2))
        #expect(ledger.hasEnded(3) == isEnding)
    }

    @Test("A silent place is reported once per session")
    func unansweredPlaceIsReportedOnce() {
        var ledger = InappSessionLedger()

        let reported = ledger.recordUnanswered("place")
        let repeated = ledger.recordUnanswered("place")
        let otherPlace = ledger.recordUnanswered("other-place")

        #expect(reported)
        #expect(!repeated)
        #expect(otherPlace)
    }
}
