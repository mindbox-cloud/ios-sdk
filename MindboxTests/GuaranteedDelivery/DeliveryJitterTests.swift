//
//  DeliveryJitterTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Delivery queue spread of pauses")
struct DeliveryJitterTests {

    private final class Draws: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [ClosedRange<Double>] = []

        var ranges: [ClosedRange<Double>] {
            lock.withLock { storage }
        }

        func draw(from range: ClosedRange<Double>, pick: (ClosedRange<Double>) -> Double) -> Double {
            lock.withLock { storage.append(range) }
            return pick(range)
        }
    }

    private func growOnce(_ manager: DeliveryRetryDelayManager) {
        manager.register(.serverFailure, transactionId: "retried", isRetry: true)
        _ = manager.completeRound()
    }

    @Test("G12: the first 429 pause is the lower bound of the range, the next one doubles it")
    func throttlePauseFromLowerBound() {
        let manager = DeliveryPauseManager(now: { 0 }, random: \.lowerBound)

        #expect(manager.register(.throttled, for: "key") == 150)
        #expect(manager.register(.throttled, for: "key") == 300)
    }

    @Test("G12: the first 429 pause is the upper bound of the range, the next one doubles it")
    func throttlePauseFromUpperBound() {
        let manager = DeliveryPauseManager(now: { 0 }, random: \.upperBound)

        #expect(manager.register(.throttled, for: "key") == 250)
        #expect(manager.register(.throttled, for: "key") == 500)
    }

    @Test("G12: the 429 pause never exceeds an hour")
    func throttlePauseIsCapped() {
        let manager = DeliveryPauseManager(now: { 0 }, random: \.upperBound)

        let pauses = (0..<10).compactMap { _ in manager.register(.throttled, for: "key") }

        #expect(pauses.last == 3600)
        #expect(pauses.allSatisfy { $0 <= 3600 })
    }

    @Test("The 429 pause draws from 150...250 by default")
    func throttlePauseDefaultRange() {
        let draws = Draws()
        let manager = DeliveryPauseManager(now: { 0 }, random: { draws.draw(from: $0, pick: \.lowerBound) })

        _ = manager.register(.throttled, for: "key")

        #expect(draws.ranges == [150...250])
    }

    @Test("G17: the retry step takes the lower bound of the spread")
    func retryDelayLowerBound() {
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 3600, random: \.lowerBound)

        #expect(manager.current == 45)
    }

    @Test("G17: the retry step takes the upper bound of the spread")
    func retryDelayUpperBound() {
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 3600, random: \.upperBound)

        #expect(manager.current == 75)
    }

    @Test("G19: reads within one step give one value and one draw")
    func oneDrawPerStep() {
        let draws = Draws()
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 3600, random: { draws.draw(from: $0, pick: \.upperBound) })
        #expect(draws.ranges.count == 1)

        let first = manager.current
        let second = manager.current
        let round = manager.completeRound()

        #expect(first == second)
        #expect(second == round)
        #expect(draws.ranges == [0.75...1.25])
    }

    @Test("G19: growing the step draws a new factor")
    func growthDrawsAgain() {
        let draws = Draws()
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 3600, random: { draws.draw(from: $0, pick: \.upperBound) })

        growOnce(manager)

        #expect(draws.ranges.count == 2)
        #expect(manager.current == 150)
        #expect(draws.ranges.count == 2)
    }

    @Test("G19: returning to the first step draws a new factor")
    func returnToFirstStepDrawsAgain() {
        let draws = Draws()
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 3600, random: { draws.draw(from: $0, pick: \.lowerBound) })
        growOnce(manager)
        let beforeReturn = draws.ranges.count

        manager.register(.delivered, transactionId: "retried", isRetry: true)

        #expect(draws.ranges.count == beforeReturn + 1)
        #expect(manager.current == 45)
    }

    @Test("Reset from a grown step draws a new factor")
    func resetFromGrownStepDrawsAgain() {
        let draws = Draws()
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 3600, random: { draws.draw(from: $0, pick: \.lowerBound) })
        growOnce(manager)
        let beforeReset = draws.ranges.count

        manager.reset()

        #expect(draws.ranges.count == beforeReset + 1)
        #expect(manager.current == 45)
    }

    @Test("Reset at the first step does not draw and keeps the value")
    func resetAtFirstStepKeepsTheFactor() {
        let draws = Draws()
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 3600, random: { draws.draw(from: $0, pick: \.upperBound) })
        let before = manager.current

        manager.reset()

        #expect(draws.ranges.count == 1)
        #expect(manager.current == before)
    }

    @Test("Growth at the ceiling does not draw and keeps the value")
    func growthAtTheCeilingKeepsTheFactor() {
        let draws = Draws()
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 120, random: { draws.draw(from: $0, pick: \.upperBound) })
        growOnce(manager)
        let atCeiling = draws.ranges.count
        let before = manager.current

        growOnce(manager)

        #expect(draws.ranges.count == atCeiling)
        #expect(manager.current == before)
    }

    @Test("The step that reaches the maximum is spread too")
    func spreadAppliesToTheMaximumStep() {
        let manager = DeliveryRetryDelayManager(firstDelay: 60, maxDelay: 120, random: \.upperBound)

        growOnce(manager)
        growOnce(manager)

        #expect(manager.current == 150)
    }
}
