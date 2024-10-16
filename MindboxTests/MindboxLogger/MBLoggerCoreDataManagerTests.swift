//
//  MBLoggerCoreDataManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest
import MindboxLogger
@testable import Mindbox

// swiftlint:disable force_unwrapping

final class MBLoggerCoreDataManagerTests: XCTestCase {
    var manager: MBLoggerCoreDataManager!

    override func setUp() {
        super.setUp()
        manager = MBLoggerCoreDataManager.shared
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func test_measure_create() throws {
        try manager.deleteAll()
        measure {
            let fetchExpectation = XCTestExpectation(description: "Fetch created log")
            let message = "Test message"
            let timestamp = Date()
            manager.create(message: message, timestamp: timestamp) {
                fetchExpectation.fulfill()
            }
            wait(for: [fetchExpectation], timeout: 2.0)
        }
    }

    func test_measure_create_10_000() throws {
        try manager.deleteAll()
        measure {
            let logsCount = 10_000
            let fetchExpectation = XCTestExpectation(description: "Fetch created log")
            fetchExpectation.expectedFulfillmentCount = logsCount
            let message = "Test message"
            let timestamp = Date()
            for _ in 0..<logsCount {
                manager.create(message: message, timestamp: timestamp) {
                    fetchExpectation.fulfill()
                }
            }

            wait(for: [fetchExpectation], timeout: 100.0)
        }
    }

    func testCreate() throws {
        try manager.deleteAll()

        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        let message = "Test message"
        let timestamp = Date()
        manager.create(message: message, timestamp: timestamp) {
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation], timeout: 3.0)

        let fetchResult = try self.manager.fetchPeriod(timestamp, timestamp)
        XCTAssertEqual(fetchResult.count, 1, "Должно быть извлечено 1 сообщение")
        XCTAssertEqual(fetchResult[0].message, message, "Сообщение должно совпадать")
        XCTAssertEqual(fetchResult[0].timestamp, timestamp, "Временная метка должна совпадать")
    }

    func testFetchFirstLog() throws {
        try manager.deleteAll()

        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let timestamp1 = Date().addingTimeInterval(-60)
        let timestamp2 = Date().addingTimeInterval(-30)
        let timestamp3 = Date()

        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        fetchExpectation.expectedFulfillmentCount = 3

        manager.create(message: message1, timestamp: timestamp1) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message2, timestamp: timestamp2) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message3, timestamp: timestamp3) {
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation], timeout: 5.0)

        let fetchResult = try self.manager.getFirstLog()
        XCTAssertNotNil(fetchResult)
        XCTAssertEqual(fetchResult!.message, message1)
        XCTAssertEqual(fetchResult!.timestamp, timestamp1)
    }

    func testFetchLastLog() throws {
        try manager.deleteAll()

        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let timestamp1 = Date().addingTimeInterval(-60)
        let timestamp2 = Date().addingTimeInterval(-30)
        let timestamp3 = Date()
        manager.create(message: message1, timestamp: timestamp1)
        manager.create(message: message2, timestamp: timestamp2)
        manager.create(message: message3, timestamp: timestamp3)

        let fetchExpectation = XCTestExpectation(description: "Fetch last log")

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            do {
                let fetchResult = try self.manager.getLastLog()
                XCTAssertEqual(fetchResult!.message, message3)
                XCTAssertEqual(fetchResult!.timestamp, timestamp3)
                fetchExpectation.fulfill()
            } catch {}
        }

        wait(for: [fetchExpectation], timeout: 5.0)
    }

    func testFetchPeriod() throws {
        try manager.deleteAll()

        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let timestamp1 = Date().addingTimeInterval(-60)
        let timestamp2 = Date().addingTimeInterval(-30)
        let timestamp3 = Date()

        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        fetchExpectation.expectedFulfillmentCount = 3

        manager.create(message: message1, timestamp: timestamp1) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message2, timestamp: timestamp2) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message3, timestamp: timestamp3) {
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation], timeout: 5.0)

        let fetchResult = try self.manager.fetchPeriod(timestamp1, timestamp2)
        XCTAssertEqual(fetchResult.count, 2)
        XCTAssertEqual(fetchResult[0].message, message1)
        XCTAssertEqual(fetchResult[0].timestamp, timestamp1)
        XCTAssertEqual(fetchResult[1].message, message2)
        XCTAssertEqual(fetchResult[1].timestamp, timestamp2)
    }

    func testDelete_10_percents() throws {
        try manager.deleteAll()

        let message = "testDelete_10_percents"

        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2023
        dateComponents.month = 1
        dateComponents.day = 2
        dateComponents.hour = 12
        dateComponents.minute = 0
        dateComponents.second = 0
        dateComponents.timeZone = TimeZone(abbreviation: "UTC")

        let specificDate = calendar.date(from: dateComponents)!

        let cycleCount = 10
        let fetchExpectation = XCTestExpectation(description: "Fetch logs for period")
        fetchExpectation.expectedFulfillmentCount = cycleCount

        for _ in 0..<cycleCount {
            manager.create(message: message, timestamp: specificDate) {
                fetchExpectation.fulfill()
            }
        }

        wait(for: [fetchExpectation], timeout: 5.0)

        let fetchResult = try self.manager.fetchPeriod(specificDate, specificDate)
        XCTAssertEqual(fetchResult.count, 10)

        try manager.delete()

        let fetchResultAfterDeletion = try manager.fetchPeriod(specificDate.addingTimeInterval(-60), specificDate)
        fetchResultAfterDeletion.forEach {
            XCTAssertEqual($0.message, "testDelete_10_percents")
        }
    }
}
