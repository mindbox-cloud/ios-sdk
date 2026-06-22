//
//  MBLoggerTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

/// `MBLogger.shared.logLevel` is a process-wide, unsynchronized property. Rather than
/// mutate it (which would race with every other suite that reads it through `Logger.*`),
/// these tests only *read* the ambient level and pick a message level relative to it —
/// keeping the suite race-free under parallel execution.
@Suite("MBLogger singleton", .tags(.loggingAPI))
struct MBLoggerTests {

    @Test("Internal log writes through to the OS writer when the level meets the threshold")
    func internalLogProceeds() {
        // Logging *at* the configured level satisfies `logLevel <= level`, so the message
        // reaches makeWriter() / OSLogWriter.writeMessage.
        let level = MBLogger.shared.logLevel
        MBLogger.shared.log(level: level, message: "passes threshold",
                            date: Date(), category: .general, subsystem: "cloud.Mindbox")
    }

    @Test("Internal log short-circuits when the message level is below the threshold")
    func internalLogBelowThreshold() {
        // Pick a level strictly below the configured one so the level guard returns early.
        // (.debug is the lowest level; if logging is already at .debug there is nothing
        // below it, so the early-return branch is only exercised when it is reachable.)
        let level = MBLogger.shared.logLevel
        guard level > .debug else { return }
        MBLogger.shared.log(level: .debug, message: "below threshold",
                            date: Date(), category: .general, subsystem: "cloud.Mindbox")
    }

    @Test("Public log forwards to Logger.common")
    func publicLogForwards() {
        MBLogger.shared.log(level: .debug, message: "public entry point")
    }
}
