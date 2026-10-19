//
//  MBLoggerTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

// `MBLogger.shared.logLevel` is process-global and unsynchronized: read it, never set it; suites run in parallel.
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
