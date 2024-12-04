//
//  StringExtensionsTests.swift
//  MindboxTests
//
//  Created by ENotniy on 29.05.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

final class StringExtensionsTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_parseTimeSpanToMillis() throws {
        let testPositiveCases: Array = [
            (str: "0:0:0.1234567", result: 123),
            (str: "0:0:0.4567890", result: 456),
            (str: "0:0:0.1", result: 100),
            (str: "0:0:0.01", result: 10),
            (str: "0:0:0.001", result: 1),
            (str: "0:0:0.0001", result: 0),
            (str: "01.01:01:01.10", result: 90061100),
            (str: "1.1:1:1.1", result: 90061100),
            (str: "1.1:1:1", result: 90061000),
            (str: "99.23:59:59", result: 8639999000),
            (str: "999.23:59:59", result: 86399999000),
            (str: "6:12:14", result: 22334000),
            (str: "6.12:14:45", result: 562485000),
            (str: "1.00:00:00", result: 86400000),
            (str: "0.00:00:00.0", result: 0),
            (str: "00:00:00", result: 0),
            (str: "0:0:0", result: 0),
            (str: "-0:0:0", result: 0),
            (str: "-0:0:0.001", result: -1),
            (str: "-1.0:0:0", result: -86400000),
            (str: "10675199.02:48:05.4775807", result: 922337203685477),
            (str: "-10675199.02:48:05.4775808", result: -922337203685477)
        ]

        for (str, result) in testPositiveCases {
            XCTContext.runActivity(named: "string(\(str)) parse to \(String(describing: result))") { _ in
                do {
                    let milliseconds = try String(str).parseTimeSpanToMillis()
                    XCTAssertEqual(milliseconds, Int64(result))
                } catch {
                    XCTFail("Throw error for \(str) but expected \(String(describing: result))")
                }
            }
        }
    }

    func test_parseTimeSpanToMillisNegative() throws {
        let testCases: Array = [
            "6",
            "6:12",
            "1.6:12",
            "1.6:12.1",
            "6.24:14:45",
            "6.99:14:45",
            "6.00:24:99",
            "6.00:99:45",
            "6.00:60:45",
            "6.00:44:60",
            "6.99:99:99",
            "1:1:1:1:1",
            "qwe",
            "",
            "999999999:0:0",
            "0:0:0.12345678",
            ".0:0:0.1234567",
            "0:0:0.",
            "0:000:0",
            "00:000:00",
            "000:00:00",
            "00:00:000",
            "+0:0:0",
            "12345678901234567890.00:00:00.00"
        ]

        for str in testCases {
            try XCTContext.runActivity(named: "string(\(str)) parse with error") { _ in
                XCTAssertThrowsError(try String(str).parseTimeSpanToMillis()) { error in
                    XCTAssertEqual((error as NSError).domain, "Invalid timeSpan format")
                }
            }
        }
    }
}
