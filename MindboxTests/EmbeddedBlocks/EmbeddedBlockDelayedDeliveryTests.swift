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
        let center = NotificationCenter()
        var isInBackground = false
        let delivery: EmbeddedBlockDelayedDelivery

        init() {
            var background = { false }
            delivery = EmbeddedBlockDelayedDelivery(isInBackground: { background() },
                                                    notificationCenter: center,
                                                    schedule: { [scheduler] in scheduler.schedule($0, $1) })
            background = { [weak self] in self?.isInBackground ?? false }
        }

        func enterForeground() {
            center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        }
    }

    @Test("An answer is delivered when its delay runs out")
    func answerIsDeliveredAfterTheDelay() {
        let rig = Rig()
        var delivered = 0

        rig.delivery.schedule(place: "stories", inappId: "a", after: 5) { delivered += 1 }

        #expect(delivered == 0)
        #expect(rig.scheduler.lastDelay == 5)

        rig.scheduler.fireAll()

        #expect(delivered == 1)
    }

    @Test("A newer answer for the place replaces the one waiting")
    func newerAnswerReplacesTheWaitingOne() {
        let rig = Rig()
        var delivered: [String] = []

        rig.delivery.schedule(place: "stories", inappId: "a", after: 5) { delivered.append("a") }
        rig.delivery.schedule(place: "stories", inappId: "b", after: 5) { delivered.append("b") }
        rig.scheduler.fireAll()

        #expect(delivered == ["b"])
    }

    @Test("Cancelling drops the waiting answer")
    func cancelDropsTheWaitingAnswer() {
        let rig = Rig()
        var delivered = 0

        rig.delivery.schedule(place: "stories", inappId: "a", after: 5) { delivered += 1 }
        rig.delivery.cancel(place: "stories")
        rig.scheduler.fireAll()

        #expect(delivered == 0)
    }

    @Test("A delay that runs out in the background is delivered on return")
    func backgroundExpiryIsDeliveredOnReturn() {
        let rig = Rig()
        var delivered = 0
        rig.delivery.schedule(place: "stories", inappId: "a", after: 5) { delivered += 1 }
        rig.isInBackground = true

        rig.scheduler.fireAll()
        #expect(delivered == 0)

        rig.isInBackground = false
        rig.enterForeground()

        #expect(delivered == 1)
    }

    @Test("Only the in-app that is waiting at the place counts as waiting")
    func waitingIsPerPlaceAndInapp() {
        let rig = Rig()

        rig.delivery.schedule(place: "stories", inappId: "a", after: 5) {}

        #expect(rig.delivery.isWaiting(place: "stories", for: "a"))
        #expect(!rig.delivery.isWaiting(place: "stories", for: "b"))
        #expect(!rig.delivery.isWaiting(place: "promo", for: "a"))

        rig.scheduler.fireAll()

        #expect(!rig.delivery.isWaiting(place: "stories", for: "a"))
    }
}
