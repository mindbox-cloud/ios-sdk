//
//  EmbeddedBlockWaitBudgetTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
@_spi(Internal) @testable import Mindbox

/// A fake-clock quantity, not a real deadline: nothing here is waited out.
private let budgetSeconds: TimeInterval = 0.4

/// Neither the clock nor the scheduler here is real. How much of the budget is "already spent" the
/// tests dictate with the substituted clock, and "time is up" happens on their command. Nothing is
/// waited out in real time: the budget is arithmetic over what was spent, and checking it with a
/// stopwatch would mean paying half a second per test and flaking on a busy runner.
///
/// Hence the main assertion of most tests — not "expired or not", but the delay the countdown was
/// armed with: that delay is the remainder of the budget.
///
/// Going to the background and returning go through each bed's own notification center: on the
/// global one such a notification would reach the blocks of tests running next to it.
@Suite("Embedded block wait budget", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockWaitBudgetTests {

    @Test("A budget that is never paused expires on its own")
    func unpausedBudgetExpires() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()

        #expect(bed.scheduler.lastDelay == budgetSeconds)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// While nobody is waiting for the block, the budget is not spent and does not expire.
    @Test("A paused budget does not expire")
    func pausedBudgetDoesNotExpire() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.budget.pause()
        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
        #expect(bed.budget.isRunning == false)
    }

    /// The main point: a pause stops the count, it does not start it over. Almost everything is
    /// spent, so after resuming the countdown is armed for the tiny remainder — not the full budget.
    @Test("Resuming continues the remaining budget instead of granting a new one")
    func resumeContinuesTheRemainder() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.clock.advance(budgetSeconds - 0.02)
        bed.budget.pause()

        bed.budget.armIfNeeded()

        #expect(isClose(bed.scheduler.lastDelay, to: 0.02))

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// Exactly the scenario that makes a resetting pause unusable: a user flipping between apps
    /// must not be able to stretch the block's wait indefinitely.
    @Test("Repeated pause and resume cannot stretch the budget past its duration")
    func repeatedPausesCannotStretchTheBudget() {
        let bed = BudgetBed()

        for _ in 0..<5 {
            bed.budget.armIfNeeded()
            bed.clock.advance(budgetSeconds / 4)
            bed.budget.pause()
        }

        #expect(bed.expirations == 0)

        // Five stretches of a quarter each — the budget is spent in full, and the next arm does
        // not give the block a single second more.
        bed.budget.armIfNeeded()

        #expect(bed.scheduler.lastDelay == 0)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// A new attempt is another matter: it is waited for with the full budget.
    @Test("Reset gives the next attempt a full budget again")
    func resetGrantsAFullBudget() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.clock.advance(budgetSeconds - 0.02)
        bed.budget.reset()

        bed.budget.armIfNeeded()

        #expect(bed.scheduler.lastDelay == budgetSeconds)
    }

    @Test("Reset stops a running budget")
    func resetStopsTheCountdown() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.budget.reset()
        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
    }

    /// The budget is needed only while the outcome is unknown and the block is visible — the
    /// container knows that, and its answer is asked on every arm.
    @Test("A budget nobody needs is not armed at all")
    func unneededBudgetIsNotArmed() {
        let bed = BudgetBed(isNeeded: false)

        bed.budget.armIfNeeded()

        #expect(bed.budget.isRunning == false)
        #expect(bed.scheduler.lastDelay == nil)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
    }

    // MARK: - Clock

    /// A clock jumping backwards must not shrink what was spent: the stretch counts as zero at
    /// worst, and the block never waits past its budget. The real clock is monotonic and cannot
    /// jump, so the guard matters for the seam and against regressions back to `Date`.
    @Test("A clock that jumps backwards does not shrink the spent budget")
    func backwardClockJumpDoesNotShrinkSpentBudget() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.clock.advance(-100)
        bed.budget.pause()

        bed.budget.armIfNeeded()

        #expect(bed.scheduler.lastDelay == budgetSeconds)
    }

    // MARK: - Background

    /// While the app is in the background nobody waits for the block — so the budget must not be
    /// spent either.
    @Test("Going to the background pauses a running budget")
    func backgroundPausesTheCountdown() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.enterBackground()

        #expect(bed.budget.isRunning == false)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
    }

    /// And exactly what the spent-time accounting exists for: returning from the background
    /// continues the budget from the remainder instead of granting it anew.
    @Test("Returning from the background continues the remaining budget")
    func foregroundContinuesTheRemainder() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.clock.advance(budgetSeconds - 0.02)
        bed.enterBackground()
        bed.enterForeground()

        #expect(isClose(bed.scheduler.lastDelay, to: 0.02))

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

    /// A background that finds the block outside a countdown cannot spend anything: the next
    /// attempt gets the budget in full.
    @Test("Going to the background outside a countdown consumes nothing")
    func backgroundOutsideCountdownConsumesNothing() {
        let bed = BudgetBed()

        bed.enterBackground()
        bed.clock.advance(budgetSeconds)

        bed.budget.armIfNeeded()

        #expect(bed.scheduler.lastDelay == budgetSeconds)
    }

    /// Returning from the background to a block nobody waits for does not resurrect the countdown:
    /// whether it is needed is the container's call, asked on every arm.
    @Test("Returning from the background does not arm a budget nobody needs")
    func foregroundDoesNotArmAnUnneededBudget() {
        let bed = BudgetBed(isNeeded: false)

        bed.enterForeground()

        #expect(bed.budget.isRunning == false)
        #expect(bed.scheduler.lastDelay == nil)
    }

    // MARK: - Arming

    /// Arming is idempotent: entering the window, returning from the background and reloading call
    /// it in any order, and a second call must not start a second countdown.
    @Test("Arming twice runs a single countdown")
    func armingTwiceRunsOneCountdown() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.budget.armIfNeeded()
        bed.scheduler.fireAll()

        // Had two countdowns been armed, there would be as many expirations.
        #expect(bed.expirations == 1)
    }
}

/// The budget remainder is arithmetic over `Double`, so it is compared with a tolerance.
private func isClose(_ value: TimeInterval?, to expected: TimeInterval) -> Bool {
    guard let value else { return false }

    return abs(value - expected) < 0.0001
}

/// The shared budget bed plus an expiration counter: here the budget is tested on its own, so
/// `isNeeded` is set by the test directly instead of being asked from the container.
@MainActor
private final class BudgetBed {

    private let bed = EmbeddedBlockWaitBudgetBed(duration: budgetSeconds)

    private(set) var expirations = 0

    var budget: EmbeddedBlockWaitBudget { bed.budget }
    var clock: TestClock { bed.clock }
    var scheduler: TestScheduler { bed.scheduler }

    init(isNeeded: Bool = true) {
        bed.budget.isNeeded = { isNeeded }
        bed.budget.onExpire = { [weak self] in
            self?.expirations += 1
        }
    }

    func enterBackground() {
        bed.enterBackground()
    }

    func enterForeground() {
        bed.enterForeground()
    }
}
