//
//  LogStoreTrimmerTests.swift
//  MindboxLoggerTests
//
//  Created by Sergei Semko on 9/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("LogStoreTrimmer policy", .tags(.storage, .trimming))
struct LogStoreTrimmerTests {

    // MARK: - Fakes

    private final class StubMeasurer: DatabaseSizeMeasuring {
        var size: Int
        var calls: Int = 0
        init(size: Int) { self.size = size }
        func sizeKB() -> Int { calls += 1; return size }
    }

    private func makeConfig(
        limit: Int = 128,
        lowWater: Double = 0.85,
        min: Double = 0.05,
        max: Double = 0.50,
        cooldown: TimeInterval = 10
    ) -> LoggerDBConfig {
        LoggerDBConfig(
            dbSizeLimitKB: limit,
            lowWaterRatio: lowWater,
            minDeleteFraction: min,
            maxDeleteFraction: max,
            batchSize: 15,
            writesPerTrimCheck: 5,
            trimCooldownSec: cooldown
        )
    }

    private func makeTrimmer(
        size: Int,
        config: LoggerDBConfig? = nil,
        start: Date = Date(timeIntervalSince1970: 0)
    ) -> (LogStoreTrimmer, StubMeasurer, ManualClock) {
        let cfg = config ?? makeConfig()
        let measurer = StubMeasurer(size: size)
        let clock = ManualClock(start)
        let trimmer = LogStoreTrimmer(config: cfg, sizeMeasurer: measurer, clock: clock)
        return (trimmer, measurer, clock)
    }

    // MARK: - computeTrimFraction

    @Test("Returns nil at or below the limit")
    func computeTrimFractionReturnsNilBelowOrEqualLimit() {
        let (trimmer, _, _) = makeTrimmer(size: 0, config: makeConfig(limit: 100))
        #expect(trimmer.computeTrimFraction(sizeKB: 100, limitKB: 100) == nil)
        #expect(trimmer.computeTrimFraction(sizeKB: 99, limitKB: 100) == nil)
    }

    @Test("Clamps to the minimum fraction just over the limit")
    func computeTrimFractionRespectsMin() {
        // limit=100, lowWater=0.98 -> target=98; size=101 -> raw ≈ 0.0297 < min(0.05) -> 0.05.
        let (trimmer, _, _) = makeTrimmer(size: 0, config: makeConfig(limit: 100, lowWater: 0.98, min: 0.05, max: 0.5))
        let fraction = trimmer.computeTrimFraction(sizeKB: 101, limitKB: 100)
        #expect(fraction != nil)
        #expect(abs((fraction ?? 0) - 0.05) < 1e-9)
    }

    @Test("Passes through a raw fraction inside [min, max]")
    func computeTrimFractionPassesThrough() {
        let (trimmer, _, _) = makeTrimmer(size: 0, config: makeConfig(limit: 100, lowWater: 0.8, min: 0.05, max: 0.5))
        #expect(trimmer.computeTrimFraction(sizeKB: 100, limitKB: 100) == nil)
        // raw ≈ (101-80)/101 ≈ 0.2079
        let fraction = trimmer.computeTrimFraction(sizeKB: 101, limitKB: 100)
        #expect(abs((fraction ?? 0) - 0.2079) < 1e-3)
    }

    @Test("Caps at the maximum fraction when way over the limit")
    func computeTrimFractionCapsAtMax() {
        let (trimmer, _, _) = makeTrimmer(size: 0, config: makeConfig(limit: 100, lowWater: 0.8, min: 0.05, max: 0.5))
        let fraction = trimmer.computeTrimFraction(sizeKB: 10_000, limitKB: 100)
        #expect(abs((fraction ?? 0) - 0.5) < 1e-9)
    }

    // MARK: - maybeTrim

    @Test("Uses the precomputed size and never calls the measurer")
    func maybeTrimUsesPrecomputedSize() {
        let (trimmer, measurer, _) = makeTrimmer(size: 10_000)
        var received: Double?
        _ = trimmer.maybeTrim(precomputedSizeKB: 129) { received = $0 }
        #expect(measurer.calls == 0)
        #expect(received != nil)
    }

    @Test("Deletes when over the limit, then honours the cooldown window")
    func maybeTrimCallsDeleteAndSetsCooldown() {
        let cfg = makeConfig(limit: 100, lowWater: 0.8, min: 0.05, max: 0.5, cooldown: 10)
        let (trimmer, measurer, clock) = makeTrimmer(size: 120, config: cfg)

        var calls = 0
        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { _ in calls += 1 }
        #expect(measurer.calls == 1)
        #expect(calls == 1)

        // Under cooldown — must not trim.
        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { _ in Issue.record("must not trim under cooldown") }
        #expect(calls == 1)

        // 9s in — still under the 10s cooldown.
        clock.advance(9)
        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { _ in Issue.record("must not trim under cooldown") }
        #expect(calls == 1)

        // At 10s the cooldown has elapsed.
        clock.advance(1)
        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { _ in calls += 1 }
        #expect(calls == 2)
    }

    @Test("Rethrows the error raised by the delete closure")
    func maybeTrimRethrows() {
        let (trimmer, _, _) = makeTrimmer(size: 10_000)
        enum E: Error { case boom }
        #expect(throws: E.self) {
            try trimmer.maybeTrim(precomputedSizeKB: nil) { _ in throw E.boom }
        }
    }

    @Test("resetCooldown allows trimming again immediately")
    func resetCooldownAllowsTrimAgain() {
        let (trimmer, _, _) = makeTrimmer(size: 10_000)
        var count = 0
        _ = trimmer.maybeTrim { _ in count += 1 }
        #expect(count == 1)

        _ = trimmer.maybeTrim { _ in count += 1 } // still under cooldown
        #expect(count == 1)

        trimmer.resetCooldown()
        _ = trimmer.maybeTrim { _ in count += 1 }
        #expect(count == 2)
    }
}
