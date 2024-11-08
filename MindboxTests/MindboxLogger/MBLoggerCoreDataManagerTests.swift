//
//  MBLoggerCoreDataManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import MindboxLogger
@testable import Mindbox

// swiftlint:disable force_unwrapping

final class MBLoggerCoreDataManagerTests: XCTestCase {
    
    private var batchSizeConstant = MBLoggerCoreDataManager.shared.debugBatchSize
    
    var manager: MBLoggerCoreDataManager!

    override func setUp() {
        super.setUp()
        manager = MBLoggerCoreDataManager.shared
        try? manager.deleteAll()
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

    // bufferSize - time
    //  5 - 1.948
    // 10 - 0.956
    // 15 - 0.654
    // 20 - 0.479
    // 25 - 0.380
    // 50 - 0.183
    func test_measure_create_10_000() throws {
        let logsCount = 10_000
        measure {
            let fetchExpectation = XCTestExpectation(description: "Fetch created log")
            fetchExpectation.expectedFulfillmentCount = logsCount
            let message = "Test message "
            for i in 0..<logsCount {
                manager.create(message: message + i.description, timestamp: Date().addingTimeInterval(Double(i))) {
                    fetchExpectation.fulfill()
                }
            }

            wait(for: [fetchExpectation], timeout: 100.0)
            NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
        }
        
        let remainingLogs = try manager.fetchPeriod(Date.distantPast, Date.distantFuture)
        XCTAssertEqual(remainingLogs.count, logsCount * 10)
        
        let fetchExpectationLast = XCTestExpectation(description: "Fetch last log")
        
        do {
            let fetchResult = try self.manager.getLastLog()
            XCTAssertEqual(fetchResult!.message, "Test message 9999")
            fetchExpectationLast.fulfill()
        } catch {}
        wait(for: [fetchExpectationLast], timeout: 5.0)
    }

    func testCreateWithBatch() throws {
        let countOfManuallyCreatedMessages = 1
        
        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        let message = "Test message"
        let timestamp = Date()
        manager.create(message: message, timestamp: timestamp) {
            fetchExpectation.fulfill()
        }

        for i in 1...batchSizeConstant - countOfManuallyCreatedMessages {
            manager.create(message: i.description, timestamp: Date().addingTimeInterval(Double(i) * 10)) {
                fetchExpectation.fulfill()
            }
        }
        
        wait(for: [fetchExpectation], timeout: 3.0)
        
        let fetchPeriodExpectation = XCTestExpectation(description: "Fetch period logs")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            do {
                let fetchResult = try self.manager.fetchPeriod(timestamp, timestamp)
                XCTAssertEqual(fetchResult.count, 1, "One message should be extracted")
                XCTAssertEqual(fetchResult.first?.message, message, "The message must match")
                XCTAssertEqual(fetchResult.first?.timestamp, timestamp, "The timestamp must match")
                fetchPeriodExpectation.fulfill()
            } catch {}
        }
        
        wait(for: [fetchPeriodExpectation], timeout: 5.0)
    }

    func testFetchFirstLog() throws {
        let countOfManuallyCreatedMessages = 3
        
        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let timestamp1 = Date().addingTimeInterval(-60)
        let timestamp2 = Date().addingTimeInterval(-30)
        let timestamp3 = Date()

        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        fetchExpectation.expectedFulfillmentCount = batchSizeConstant

        manager.create(message: message1, timestamp: timestamp1) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message2, timestamp: timestamp2) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message3, timestamp: timestamp3) {
            fetchExpectation.fulfill()
        }
        
        for i in 1...batchSizeConstant - countOfManuallyCreatedMessages {
            manager.create(message: i.description, timestamp: Date()) {
                fetchExpectation.fulfill()
            }
        }

        wait(for: [fetchExpectation], timeout: 5.0)

        let fetchResult = try self.manager.getFirstLog()
        XCTAssertNotNil(fetchResult)
        XCTAssertEqual(fetchResult!.message, message1)
        XCTAssertEqual(fetchResult!.timestamp, timestamp1)
    }

    func testFetchLastLog() throws {
        let countOfManuallyCreatedMessages = 3
        
        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let timestamp1 = Date().addingTimeInterval(-60)
        let timestamp2 = Date().addingTimeInterval(-30)
        let timestamp3 = Date()
        
        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        fetchExpectation.expectedFulfillmentCount = batchSizeConstant
        
        manager.create(message: message1, timestamp: timestamp1) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message2, timestamp: timestamp2) {
            fetchExpectation.fulfill()
        }
        
        for i in 1...batchSizeConstant - countOfManuallyCreatedMessages {
            manager.create(message: i.description, timestamp: Date().addingTimeInterval(Double(-i))) {
                fetchExpectation.fulfill()
            }
        }
        
        manager.create(message: message3, timestamp: timestamp3) {
            fetchExpectation.fulfill()
        }
        
        wait(for: [fetchExpectation], timeout: 5.0)
        
        let fetchResult = try self.manager.getLastLog()
        XCTAssertEqual(fetchResult!.message, message3)
        XCTAssertEqual(fetchResult!.timestamp, timestamp3)
    }

    func testFetchPeriod() throws {
        let countOfManuallyCreatedMessages = 3

        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let timestamp1 = Date().addingTimeInterval(-60)
        let timestamp2 = Date().addingTimeInterval(-30)
        let timestamp3 = Date()

        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        fetchExpectation.expectedFulfillmentCount = batchSizeConstant * 2
        
        for i in 1...batchSizeConstant {
            manager.create(message: i.description, timestamp: Date().addingTimeInterval(Double(i) * -100)) {
                fetchExpectation.fulfill()
            }
        }

        manager.create(message: message1, timestamp: timestamp1) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message2, timestamp: timestamp2) {
            fetchExpectation.fulfill()
        }
        manager.create(message: message3, timestamp: timestamp3) {
            fetchExpectation.fulfill()
        }
        
        for i in 1...batchSizeConstant - countOfManuallyCreatedMessages {
            manager.create(message: i.description, timestamp: Date().addingTimeInterval(Double(i))) {
                fetchExpectation.fulfill()
            }
        }

        wait(for: [fetchExpectation], timeout: 5.0)

        let fetchResult = try self.manager.fetchPeriod(timestamp1, timestamp2)
        XCTAssertEqual(fetchResult.count, 2)
        XCTAssertEqual(fetchResult[0].message, message1)
        XCTAssertEqual(fetchResult[0].timestamp, timestamp1)
        XCTAssertEqual(fetchResult[1].message, message2)
        XCTAssertEqual(fetchResult[1].timestamp, timestamp2)
    }

    func testDeleteTenPercentOfAllOldRecords() throws {
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

        let cycleCount = batchSizeConstant * 2
        let fetchExpectation = XCTestExpectation(description: "Fetch logs for period")
        fetchExpectation.expectedFulfillmentCount = cycleCount

        for _ in 0..<cycleCount {
            manager.create(message: message, timestamp: specificDate) {
                fetchExpectation.fulfill()
            }
        }

        wait(for: [fetchExpectation], timeout: 5.0)

        let fetchResult = try self.manager.fetchPeriod(specificDate, specificDate)
        XCTAssertEqual(fetchResult.count, cycleCount, "Initial count should be 'cycleCount' logs.")

        try manager.deleteTenPercentOfAllOldRecords()

        let fetchResultAfterDeletion = try manager.fetchPeriod(specificDate.addingTimeInterval(-60),
                                                               specificDate)
        let expectedRemainingCount = Int(Double(cycleCount) * 0.9)
        XCTAssertEqual(fetchResultAfterDeletion.count,
                       expectedRemainingCount,
                       "After deleting 10%, there should be \(expectedRemainingCount) logs left.")

        fetchResultAfterDeletion.forEach {
            XCTAssertEqual($0.message,
                           "testDelete_10_percents",
                           "Remaining log messages should match the expected message.")
        }
    }


    func testFlushBufferWhenApplicationDidEnterBackground() throws {
        let fetchExpectationExtraLast = XCTestExpectation(description: "Fetch extra last log")
        
        for i in 1...batchSizeConstant / 2 {
            manager.create(message: "Log: \(i)", timestamp: Date().addingTimeInterval(Double(i) * 10)) {
                fetchExpectationExtraLast.fulfill()
            }
        }
        
        wait(for: [fetchExpectationExtraLast], timeout: 5.0)
        
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        let fetchExpectation = XCTestExpectation(description: "Fetch last log after didEnterBackgroundNotification")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            do {
                let fetchResult = try self.manager.getLastLog()
                XCTAssertEqual(fetchResult!.message, "Log: \(self.batchSizeConstant / 2)")
                fetchExpectation.fulfill()
            } catch {}
        }
        
        wait(for: [fetchExpectation], timeout: 5.0)
    }
    
    func testFlushBufferWhenApplicationWillTerminate() throws {
        let fetchExpectationExtraLast = XCTestExpectation(description: "Fetch extra last log")
        
        for i in 1...batchSizeConstant / 2 {
            manager.create(message: "Log: \(i)", timestamp: Date().addingTimeInterval(Double(i) * 10)) {
                fetchExpectationExtraLast.fulfill()
            }
        }
        
        wait(for: [fetchExpectationExtraLast], timeout: 5.0)
        
        NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
        
        let fetchExpectation = XCTestExpectation(description: "Fetch last log after willTerminateNotification")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            do {
                let fetchResult = try self.manager.getLastLog()
                XCTAssertEqual(fetchResult!.message, "Log: \(self.batchSizeConstant / 2)")
                fetchExpectation.fulfill()
            } catch {}
        }
        
        wait(for: [fetchExpectation], timeout: 5.0)
    }
}
