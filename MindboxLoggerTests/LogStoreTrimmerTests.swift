//
//  LogStoreTrimmerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import MindboxLogger

final class LogStoreTrimmerTests: XCTestCase {

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

    func testComputeTrimFraction_ReturnsNil_WhenBelowOrEqualLimit() {
        let cfg = makeConfig(limit: 100)
        let (trimmer, _, _) = makeTrimmer(size: 0, config: cfg)
        XCTAssertNil(trimmer.computeTrimFraction(sizeKB: 100, limitKB: 100))
        XCTAssertNil(trimmer.computeTrimFraction(sizeKB: 99,  limitKB: 100))
    }

    func testComputeTrimFraction_RespectsMin_WhenSlightlyOverLimit() {
        // For min to work, you need:
        // 1) to be SLIGHTLY above the limit (size > limit) so as not to get nil;
        // 2) to have raw < min. raw = (size - target) / size; target = limit * lowWater.
        // Let's take limit=100, lowWater=0.98 → target=98.
        // When size=101: raw ≈ (101-98)/101 ≈ 0.0297 < min(0.05) → result = 0.05.
        let cfg = makeConfig(limit: 100, lowWater: 0.98, min: 0.05, max: 0.5)
        let (trimmer, _, _) = makeTrimmer(size: 0, config: cfg)
        let f = trimmer.computeTrimFraction(sizeKB: 101, limitKB: 100)
        XCTAssertNotNil(f)
        XCTAssertEqual(f!, 0.05, accuracy: 1e-9)
    }

    func testComputeTrimFraction_PassesThrough_WhenWithinMinMax() {
        // limit=100, lowWater=0.8 → target=80, size=100 → equal to limit → nil
        let cfg = makeConfig(limit: 100, lowWater: 0.8, min: 0.05, max: 0.5)
        let (trimmer, _, _) = makeTrimmer(size: 0, config: cfg)

        let f = trimmer.computeTrimFraction(sizeKB: 100, limitKB: 100)
        XCTAssertNil(f)

        // Slightly above the limit: raw ≈ (101-80)/101 ≈ 0.2079 → between min and max
        let f2 = trimmer.computeTrimFraction(sizeKB: 101, limitKB: 100)
        XCTAssertEqual(f2!, 0.2079, accuracy: 1e-3)
    }

    func testComputeTrimFraction_CapsAtMax_WhenWayOverLimit() {
        let cfg = makeConfig(limit: 100, lowWater: 0.8, min: 0.05, max: 0.5)
        let (trimmer, _, _) = makeTrimmer(size: 0, config: cfg)
        let f = trimmer.computeTrimFraction(sizeKB: 10_000, limitKB: 100)
        XCTAssertEqual(f!, 0.5, accuracy: 1e-9)
    }

    // MARK: - maybeTrim

    func testMaybeTrim_UsesPrecomputedSize_DoesNotCallMeasurer() {
        let (trimmer, measurer, _) = makeTrimmer(size: 10_000)
        var received: Double?
        
        _ = trimmer.maybeTrim(precomputedSizeKB: 129) { fraction in
            received = fraction
        }
        XCTAssertEqual(measurer.calls, 0) // the meter was not used
        XCTAssertNotNil(received)         // the trim happened
    }

    func testMaybeTrim_CallsDelete_WhenOverLimit_AndSetsCooldown() {
        let cfg = makeConfig(limit: 100, lowWater: 0.8, min: 0.05, max: 0.5, cooldown: 10)
        let (trimmer, measurer, clock) = makeTrimmer(size: 120, config: cfg, start: Date(timeIntervalSince1970: 0))

        var calls = 0
        var fractions: [Double] = []

        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { f in
            calls += 1
            fractions.append(f)
        }
        XCTAssertEqual(measurer.calls, 1)
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(fractions.isEmpty)

        // Repeated call before the cooldown expires — should not trim
        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { _ in
            XCTFail("Should not be called under cooldown")
        }
        XCTAssertEqual(calls, 1)

        // We advance the clock by 9 seconds — still cooldown.
        clock.advance(9)
        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { _ in
            XCTFail("Should not be called under cooldown")
        }
        XCTAssertEqual(calls, 1)

        // At the 10-second mark, the cooldown ended.
        clock.advance(1)
        _ = trimmer.maybeTrim(precomputedSizeKB: nil) { f in
            calls += 1
            fractions.append(f)
        }
        XCTAssertEqual(calls, 2)
    }

    func testMaybeTrim_RethrowsErrorFromDelete() {
        let (trimmer, _, _) = makeTrimmer(size: 10_000)
        enum E: Error { case boom }

        XCTAssertThrowsError(try trimmer.maybeTrim(precomputedSizeKB: nil) { _ in
            throw E.boom
        }) { error in
            guard case E.boom = error else { return XCTFail("Wrong error") }
        }
    }

    func testResetCooldown_AllowsTrimAgainImmediately() {
        let (trimmer, _, _) = makeTrimmer(size: 10_000)

        var count = 0
        _ = trimmer.maybeTrim { _ in count += 1 }
        XCTAssertEqual(count, 1)

        // immediate repeat — should not work
        _ = trimmer.maybeTrim { _ in count += 1 }
        XCTAssertEqual(count, 1)

        // reset the cooldown — you can do it again
        trimmer.resetCooldown()
        _ = trimmer.maybeTrim { _ in count += 1 }
        XCTAssertEqual(count, 2)
    }
}
