//
//  EmbeddedBlockWaitBudgetTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
@_spi(Internal) @testable import Mindbox

private let budgetSeconds: TimeInterval = 0.4

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

    @Test("A paused budget does not expire")
    func pausedBudgetDoesNotExpire() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.budget.pause()
        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
        #expect(bed.budget.isRunning == false)
    }

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

    @Test("Repeated pause and resume cannot stretch the budget past its duration")
    func repeatedPausesCannotStretchTheBudget() {
        let bed = BudgetBed()

        for _ in 0..<5 {
            bed.budget.armIfNeeded()
            bed.clock.advance(budgetSeconds / 4)
            bed.budget.pause()
        }

        #expect(bed.expirations == 0)

        bed.budget.armIfNeeded()

        #expect(bed.scheduler.lastDelay == 0)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }

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

    @Test("Going to the background pauses a running budget")
    func backgroundPausesTheCountdown() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.enterBackground()

        #expect(bed.budget.isRunning == false)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)
    }

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

    @Test("Going to the background outside a countdown consumes nothing")
    func backgroundOutsideCountdownConsumesNothing() {
        let bed = BudgetBed()

        bed.enterBackground()
        bed.clock.advance(budgetSeconds)

        bed.enterForeground()

        #expect(bed.scheduler.lastDelay == budgetSeconds)
    }

    @Test("Returning from the background does not arm a budget nobody needs")
    func foregroundDoesNotArmAnUnneededBudget() {
        let bed = BudgetBed(isNeeded: false)

        bed.enterForeground()

        #expect(bed.budget.isRunning == false)
        #expect(bed.scheduler.lastDelay == nil)
    }

    @Test("A budget asked to arm in the background counts from the return")
    func armingInTheBackgroundCountsFromTheReturn() {
        let bed = BudgetBed()

        bed.enterBackground()
        bed.budget.armIfNeeded()

        #expect(bed.budget.isRunning == false)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)

        bed.enterForeground()

        #expect(bed.budget.isRunning)
        #expect(bed.scheduler.lastDelay == budgetSeconds)
    }

    @Test("A budget created while the app is already in the background, as after a launch into it, counts from the return: willEnterForeground, or didBecomeActive when that was missed",
          arguments: [false, true])
    func budgetCreatedInTheBackgroundCountsFromTheReturn(isWillEnterForegroundMissed: Bool) {
        let bed = BudgetBed(applicationState: .background)

        bed.budget.armIfNeeded()

        #expect(bed.budget.isRunning == false)

        bed.scheduler.fireAll()

        #expect(bed.expirations == 0)

        if isWillEnterForegroundMissed {
            bed.becomeActive()
        } else {
            bed.enterForeground()
        }

        #expect(bed.budget.isRunning)
        #expect(bed.scheduler.lastDelay == budgetSeconds)
    }

    @Test("A budget created after the app went to the background counts from the return")
    func budgetCreatedAfterTheAppLeftCountsFromTheReturn() {
        let bed = BudgetBed()
        bed.enterBackground()
        let later = bed.makeBudget()

        later.armIfNeeded()

        #expect(later.isRunning == false)

        bed.enterForeground()

        #expect(later.isRunning)
    }

    // MARK: - Arming

    @Test("Arming twice runs a single countdown")
    func armingTwiceRunsOneCountdown() {
        let bed = BudgetBed()

        bed.budget.armIfNeeded()
        bed.budget.armIfNeeded()
        bed.scheduler.fireAll()

        #expect(bed.expirations == 1)
    }
}

private func isClose(_ value: TimeInterval?, to expected: TimeInterval) -> Bool {
    guard let value else { return false }

    return abs(value - expected) < 0.0001
}

@MainActor
private final class BudgetBed {

    private let bed: EmbeddedBlockWaitBudgetBed

    private(set) var expirations = 0

    var budget: EmbeddedBlockWaitBudget { bed.budget }
    var clock: TestClock { bed.clock }
    var scheduler: TestScheduler { bed.scheduler }

    init(isNeeded: Bool = true, applicationState: UIApplication.State = .active) {
        bed = EmbeddedBlockWaitBudgetBed(duration: budgetSeconds, applicationState: applicationState)
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

    func becomeActive() {
        bed.presenceBed.becomeActive()
    }

    func makeBudget() -> EmbeddedBlockWaitBudget {
        let budget = bed.makeBudget(placeSystemName: "later-block")
        budget.isNeeded = { true }
        return budget
    }
}
