//
//  LogPrimitivesTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("Log primitives: category, level, writer, message", .tags(.loggingAPI))
struct LogPrimitivesTests {

    @Test("Every LogCategory exposes a non-empty emoji")
    func categoryEmoji() {
        #expect(LogCategory.allCases.count == 13)
        for category in LogCategory.allCases {
            #expect(!category.emoji.isEmpty, "\(category) has no emoji")
        }
        #expect(LogCategory.general.emoji == "🤖")
        #expect(LogCategory.network.emoji == "📡")
    }

    @Test("LogLevel emoji, raw values and ordering")
    func logLevel() {
        #expect(LogLevel.allCases.count == 6)
        #expect(LogLevel.none.emoji.isEmpty)
        for level in LogLevel.allCases where level != .none {
            #expect(!level.emoji.isEmpty, "\(level) has no emoji")
        }

        #expect(LogLevel.debug.rawValue == 0)
        #expect(LogLevel.none.rawValue == 5)

        #expect(LogLevel.debug < LogLevel.error)
        #expect(LogLevel.fault < LogLevel.none)
        #expect(!(LogLevel.error < LogLevel.debug))
    }

    @Test("OSLogWriter.writeMessage maps every level to an OSLogType without trapping")
    func osLogWriter() {
        let writer = OSLogWriter(subsystem: "cloud.Mindbox.UnitTest", category: "Test")
        for level in LogLevel.allCases {
            writer.writeMessage("message at \(level)", logLevel: level)
        }
    }

    @Test("LogMessage.description prefixes the UTC timestamp")
    func logMessageDescription() {
        let date = Date(timeIntervalSince1970: 1_747_017_155) // 2025-05-12T02:32:35Z
        let message = LogMessage(timestamp: date, message: "payload")
        #expect(message.description == "2025-05-12T02:32:35Z | payload")
    }
}
