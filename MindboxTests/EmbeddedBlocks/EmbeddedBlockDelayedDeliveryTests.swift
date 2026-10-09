//
//  EmbeddedBlockDelayedDeliveryTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 25.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import Testing
@testable import Mindbox

@Suite("Embedded block delayed delivery", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockDelayedDeliveryTests {

    private final class Rig {
        let scheduler = TestScheduler()
        let presence = AppPresenceBed()
        let delivery: EmbeddedBlockDelayedDelivery<String>

        init() {
            delivery = EmbeddedBlockDelayedDelivery(presence: presence.presence,
                                                    schedule: { [scheduler] in scheduler.schedule($0, $1) })
        }
    }

    private static func winner(_ inappId: String, in sessionEpoch: Int = 0) -> EmbeddedBlockDelayedWinner {
        EmbeddedBlockDelayedWinner(inappId: inappId, sessionEpoch: sessionEpoch)
    }

    @Test("An answer is delivered when its delay runs out")
    func answerIsDeliveredAfterTheDelay() {
        let rig = Rig()
        var delivered = 0

        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { _ in delivered += 1 }

        #expect(delivered == 0)
        #expect(rig.scheduler.lastDelay == 5)

        rig.scheduler.fireAll()

        #expect(delivered == 1)
    }

    @Test("A newer answer for the place replaces the one waiting")
    func newerAnswerReplacesTheWaitingOne() {
        let rig = Rig()
        var delivered: [String] = []

        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { delivered.append($0) }
        rig.delivery.schedule(place: "stories", winner: Self.winner("b"), answer: "b", after: 5) { delivered.append($0) }
        rig.scheduler.fireAll()

        #expect(delivered == ["b"])
    }

    @Test("Cancelling drops the waiting answer")
    func cancelDropsTheWaitingAnswer() {
        let rig = Rig()
        var delivered = 0

        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { _ in delivered += 1 }
        rig.delivery.cancel(place: "stories")
        rig.scheduler.fireAll()

        #expect(delivered == 0)
    }

    @Test("A delay that runs out in the background is delivered once the user is back and the return's session check is over")
    func backgroundExpiryIsDeliveredOnReturn() {
        let rig = Rig()
        var delivered = 0
        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { _ in delivered += 1 }
        rig.presence.enterBackground()

        rig.scheduler.fireAll()
        #expect(delivered == 0)

        rig.presence.returnToApp()
        #expect(delivered == 0)

        rig.presence.finishSessionCheck()

        #expect(delivered == 1)
    }

    @Test("A delay that runs out after the return but before its session check ends waits for the check")
    func expiryBeforeTheReturnsCheckWaitsForIt() {
        let rig = Rig()
        var delivered = 0
        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { _ in delivered += 1 }
        rig.presence.enterBackground()
        rig.presence.returnToApp()

        rig.scheduler.fireAll()
        #expect(delivered == 0)

        rig.presence.finishSessionCheck()

        #expect(delivered == 1)
    }

    @Test("A delay that runs out while the app is inactive is delivered once it is active again")
    func inactiveExpiryIsDeliveredOnBecomingActive() {
        let rig = Rig()
        var delivered = 0
        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { _ in delivered += 1 }
        rig.presence.applicationState = .inactive

        rig.scheduler.fireAll()
        #expect(delivered == 0)

        rig.presence.becomeActive()

        #expect(delivered == 1)
    }

    @Test("An answer parked in the background still counts as waiting")
    func parkedAnswerStillCountsAsWaiting() {
        let rig = Rig()
        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { _ in }
        rig.presence.enterBackground()
        rig.scheduler.fireAll()

        #expect(rig.delivery.isWaiting(place: "stories", for: Self.winner("a")))
    }

    @Test("Only the in-app that is waiting at the place, in the session it waits in, counts as waiting")
    func waitingIsPerPlaceAndInapp() {
        let rig = Rig()

        rig.delivery.schedule(place: "stories", winner: Self.winner("a"), answer: "a", after: 5) { _ in }

        #expect(rig.delivery.isWaiting(place: "stories", for: Self.winner("a")))
        #expect(!rig.delivery.isWaiting(place: "stories", for: Self.winner("b")))
        #expect(!rig.delivery.isWaiting(place: "promo", for: Self.winner("a")))
        #expect(!rig.delivery.isWaiting(place: "stories", for: Self.winner("a", in: 1)))

        rig.scheduler.fireAll()

        #expect(!rig.delivery.isWaiting(place: "stories", for: Self.winner("a")))
    }
}
