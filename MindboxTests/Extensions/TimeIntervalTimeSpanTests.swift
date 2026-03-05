//
//  TimeIntervalTimeSpanTests.swift
//  MindboxTests
//
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

final class TimeIntervalTimeSpanTests: XCTestCase {

    func test_toTimeSpan_zero() {
        let result = TimeInterval(0).toTimeSpan()
        XCTAssertEqual(result, "0:00:00.0000000")
    }

    func test_toTimeSpan_subSecondValues() {
        let cases: [(TimeInterval, String)] = [
            (0.1,       "0:00:00.1000000"),
            (0.001,     "0:00:00.0010000"),
            (0.1234567, "0:00:00.1234567"),
            (0.4567890, "0:00:00.4567890"),
        ]

        for (input, expected) in cases {
            XCTContext.runActivity(named: "toTimeSpan(\(input)) == \(expected)") { _ in
                XCTAssertEqual(input.toTimeSpan(), expected)
            }
        }
    }

    func test_toTimeSpan_secondsAndMinutes() {
        let cases: [(TimeInterval, String)] = [
            (1.0,    "0:00:01.0000000"),
            (59.0,   "0:00:59.0000000"),
            (60.0,   "0:01:00.0000000"),
            (61.5,   "0:01:01.5000000"),
            (3599.0, "0:59:59.0000000"),
        ]

        for (input, expected) in cases {
            XCTContext.runActivity(named: "toTimeSpan(\(input)) == \(expected)") { _ in
                XCTAssertEqual(input.toTimeSpan(), expected)
            }
        }
    }

    func test_toTimeSpan_hours() {
        let cases: [(TimeInterval, String)] = [
            (3600.0,  "1:00:00.0000000"),
            (7261.0,  "2:01:01.0000000"),
            (86399.0, "23:59:59.0000000"),
        ]

        for (input, expected) in cases {
            XCTContext.runActivity(named: "toTimeSpan(\(input)) == \(expected)") { _ in
                XCTAssertEqual(input.toTimeSpan(), expected)
            }
        }
    }

    func test_toTimeSpan_withDays() {
        let cases: [(TimeInterval, String)] = [
            (86400.0,      "1.00:00:00.0000000"),
            (90061.1,      "1.01:01:01.1000000"),
            (8639999.0,    "99.23:59:59.0000000"),
        ]

        for (input, expected) in cases {
            XCTContext.runActivity(named: "toTimeSpan(\(input)) == \(expected)") { _ in
                XCTAssertEqual(input.toTimeSpan(), expected)
            }
        }
    }

    func test_toTimeSpan_negativeValues() {
        let cases: [(TimeInterval, String)] = [
            (-0.001,    "-0:00:00.0010000"),
            (-1.0,      "-0:00:01.0000000"),
            (-86400.0,  "-1.00:00:00.0000000"),
        ]

        for (input, expected) in cases {
            XCTContext.runActivity(named: "toTimeSpan(\(input)) == \(expected)") { _ in
                XCTAssertEqual(input.toTimeSpan(), expected)
            }
        }
    }

    func test_toTimeSpan_negativeZero_isNotNegative() {
        let result = TimeInterval(-0.0).toTimeSpan()
        XCTAssertFalse(result.hasPrefix("-"), "Negative zero should not produce a minus sign")
        XCTAssertEqual(result, "0:00:00.0000000")
    }

    func test_toTimeSpan_roundTrip_withParseTimeSpanToMillis() {
        let millisecondsValues: [Int64] = [
            0, 1, 10, 100, 123, 456, 1000, 60000, 3600000,
            22334000, 86400000, 90061100, 562485000,
        ]

        for ms in millisecondsValues {
            XCTContext.runActivity(named: "round-trip for \(ms)ms") { _ in
                let seconds = TimeInterval(ms) / 1000.0
                let timeSpanString = seconds.toTimeSpan()

                do {
                    let parsedMs = try timeSpanString.parseTimeSpanToMillis()
                    XCTAssertEqual(parsedMs, ms, "Round-trip failed: \(ms)ms -> \"\(timeSpanString)\" -> \(parsedMs)ms")
                } catch {
                    XCTFail("parseTimeSpanToMillis threw for \"\(timeSpanString)\": \(error)")
                }
            }
        }
    }

    func test_toTimeSpan_typicalSDKProcessingTimes() {
        XCTContext.runActivity(named: "50ms processing time") { _ in
            XCTAssertEqual(TimeInterval(0.05).toTimeSpan(), "0:00:00.0500000")
        }

        XCTContext.runActivity(named: "250ms processing time") { _ in
            XCTAssertEqual(TimeInterval(0.25).toTimeSpan(), "0:00:00.2500000")
        }

        XCTContext.runActivity(named: "1.5s processing time") { _ in
            XCTAssertEqual(TimeInterval(1.5).toTimeSpan(), "0:00:01.5000000")
        }

        XCTContext.runActivity(named: "5s processing time") { _ in
            XCTAssertEqual(TimeInterval(5.0).toTimeSpan(), "0:00:05.0000000")
        }
    }
}
