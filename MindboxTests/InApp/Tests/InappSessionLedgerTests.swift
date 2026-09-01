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

        let offered = ledger.vouchOffer(BlockOffer(blockInappId: "block-1", inappId: "inapp-1"))
        let repeated = ledger.vouchOffer(BlockOffer(blockInappId: "block-1", inappId: "inapp-1"))
        let otherBlock = ledger.vouchOffer(BlockOffer(blockInappId: "block-2", inappId: "inapp-1"))

        #expect(offered)
        #expect(!repeated)
        #expect(otherBlock)
    }

    @Test("A show is recorded when the place shows something new, places independent")
    func showsAreRecordedPerPlaceChange() {
        var ledger = InappSessionLedger()

        let shown = ledger.recordShow("inapp-1", at: "place")
        let held = ledger.recordShow("inapp-1", at: "place")
        let changed = ledger.recordShow("inapp-2", at: "place")
        let returned = ledger.recordShow("inapp-1", at: "place")
        let otherPlace = ledger.recordShow("inapp-1", at: "other-place")

        #expect(shown)
        #expect(!held)
        #expect(changed)
        #expect(returned)
        #expect(otherPlace)
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
