//
//  MBLoggerTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

/// `logLevel` is process-wide and unsynchronized, so these tests only *read* it (mutating it
/// would race every suite that logs through `Logger.*`). They're smoke tests: each drives a
/// `log(...)` dispatch path for coverage and asserts only that it doesn't trap — the OS-log /
/// shared-CD side effects aren't observable here without a production seam.
@Suite("MBLogger singleton", .tags(.loggingAPI))
struct MBLoggerTests {

    @Test("Internal log at/above threshold runs the full write path without trapping")
    func internalLogAtThresholdDoesNotTrap() {
        let level = MBLogger.shared.logLevel
        MBLogger.shared.log(level: level, message: "passes threshold",
                            date: Date(), category: .general, subsystem: "cloud.Mindbox")
    }

    @Test("Internal log below threshold short-circuits without trapping")
    func internalLogBelowThresholdDoesNotTrap() {
        // .debug is the lowest level; if logging is already there the early-return arm is
        // unreachable, so only exercise it when a strictly-lower level exists.
        let level = MBLogger.shared.logLevel
        guard level > .debug else { return }
        MBLogger.shared.log(level: .debug, message: "below threshold",
                            date: Date(), category: .general, subsystem: "cloud.Mindbox")
    }

    @Test("Public log entry point runs without trapping")
    func publicLogDoesNotTrap() {
        MBLogger.shared.log(level: .debug, message: "public entry point")
    }
}
