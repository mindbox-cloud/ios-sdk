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

final class MBLoggerCoreDataManagerTests: XCTestCase {

    private var batchSizeConstant = MBLoggerCoreDataManager.shared.debugBatchSize

    var manager: MBLoggerCoreDataManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        manager = MBLoggerCoreDataManager.shared

        try manager.deleteAll()

        let fetchExpectation = XCTestExpectation(description: "Fetch delete all logs")
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            fetchExpectation.fulfill()
        }
        wait(for: [fetchExpectation])
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func test_measure_create_one_batch() throws {
        measure {
            let fetchExpectation = XCTestExpectation(description: "Fetch created log")
            fetchExpectation.expectedFulfillmentCount = batchSizeConstant
            createMessages(range: 1...batchSizeConstant) { _, _ in
                fetchExpectation.fulfill()
            }

            wait(for: [fetchExpectation])
        }
    }

    func test_measure_create_1_000() throws {
        let logsCount = 1_000
        measure {
            let fetchExpectation = XCTestExpectation(description: "Fetch created log")
            fetchExpectation.expectedFulfillmentCount = logsCount

            createMessages(range: 0..<logsCount, timeStrategy: .sequentialDefault) { _, _ in
                fetchExpectation.fulfill()
            }

            wait(for: [fetchExpectation])
        }
    }

    func testCreateWithBatch() throws {
        let countOfManuallyCreatedMessages = 1

        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        fetchExpectation.expectedFulfillmentCount = batchSizeConstant

        let message = "Test message"
        let timestamp = Date()
        manager.create(message: message, timestamp: timestamp) {
            fetchExpectation.fulfill()
        }

        createRemainingMessages(basedOn: countOfManuallyCreatedMessages,
                                timeStrategy: .sequential(interval: 10)
        ) { _, _ in
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation])

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

        wait(for: [fetchPeriodExpectation])
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

        createRemainingMessages(basedOn: countOfManuallyCreatedMessages) { _, _ in
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation])

        let fetchResult = try self.manager.getFirstLog()
        XCTAssertNotNil(fetchResult)
        XCTAssertEqual(fetchResult?.message, message1)
        XCTAssertEqual(fetchResult?.timestamp, timestamp1)
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

        createRemainingMessages(basedOn: countOfManuallyCreatedMessages,
                                timeStrategy: .reverseDefault
        ) { _, _ in
            fetchExpectation.fulfill()
        }

        manager.create(message: message3, timestamp: timestamp3) {
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation])

        let fetchResult = try self.manager.getLastLog()
        XCTAssertEqual(fetchResult?.message, message3)
        XCTAssertEqual(fetchResult?.timestamp, timestamp3)
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

        createRemainingMessages(timeStrategy: .reverse(interval: 100)) { _, _ in
            fetchExpectation.fulfill()
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

        createRemainingMessages(basedOn: countOfManuallyCreatedMessages,
                                timeStrategy: .sequentialDefault
        ) { _, _ in
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation])

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

        // swiftlint:disable:next force_unwrapping
        let specificDate = calendar.date(from: dateComponents)!
        // swiftlint:disable:previous force_unwrapping

        let cycleCount = batchSizeConstant * 2
        let fetchExpectation = XCTestExpectation(description: "Fetch logs for period")
        fetchExpectation.expectedFulfillmentCount = cycleCount

        createMessages(message: message,
                       range: 0..<cycleCount,
                       timeStrategy: .custom(date: specificDate, interval: 0)
        ) { _, _ in
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation])

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

        createMessages(range: 1...batchSizeConstant / 2, timeStrategy: .sequentialDefault) { _, _ in
            fetchExpectationExtraLast.fulfill()
        }

        wait(for: [fetchExpectationExtraLast])

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        let fetchExpectation = XCTestExpectation(description: "Fetch last log after didEnterBackgroundNotification")

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            do {
                let fetchResult = try self.manager.getLastLog()
                XCTAssertEqual(fetchResult?.message, "Log: \(self.batchSizeConstant / 2)")
                fetchExpectation.fulfill()
            } catch {}
        }

        wait(for: [fetchExpectation])
    }

    func testFlushBufferWhenApplicationWillTerminate() throws {
        let fetchExpectationExtraLast = XCTestExpectation(description: "Fetch extra last log")

        createMessages(range: 1...batchSizeConstant / 2, timeStrategy: .sequentialDefault) { _, _ in
            fetchExpectationExtraLast.fulfill()
        }

        wait(for: [fetchExpectationExtraLast])

        NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)

        let fetchExpectation = XCTestExpectation(description: "Fetch last log after willTerminateNotification")

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            do {
                let fetchResult = try self.manager.getLastLog()
                XCTAssertEqual(fetchResult?.message, "Log: \(self.batchSizeConstant / 2)")
                fetchExpectation.fulfill()
            } catch {}
        }

        wait(for: [fetchExpectation])
    }

    func testFlushBufferInAppExtensions() throws {
        manager = MBLoggerCoreDataManager(debugIsAppExtension: true)

        let maxCountOfLogs = Int.random(in: 1..<batchSizeConstant)

        let fetchExpectation = XCTestExpectation(description: "Fetch created log")
        fetchExpectation.expectedFulfillmentCount = maxCountOfLogs

        createMessages(range: 1...maxCountOfLogs, timeStrategy: .sequentialDefault) { index, timestamp in
            let lastLog = try? self.manager.getLastLog()
            XCTAssertEqual(lastLog?.timestamp, timestamp)
            XCTAssertEqual(lastLog?.message, "Log: \(index.description)")

            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation])

        let fetchResult = try self.manager.getLastLog()
        XCTAssertEqual(fetchResult?.message, "Log: \(maxCountOfLogs.description)")

        let remainingLogs = try manager.fetchPeriod(Date.distantPast, Date.distantFuture)
        XCTAssertEqual(remainingLogs.count, maxCountOfLogs)
    }
}

private extension MBLoggerCoreDataManagerTests {

    enum TimeStrategy {
        case none
        case sequential(interval: TimeInterval) // adds a sequential interval to the time (for example, 10 seconds, 20 seconds, etc.)
        case reverse(interval: TimeInterval) // adds a reverse interval (-10 seconds, -20 seconds, etc.)
        case custom(date: Date, interval: TimeInterval) // arbitrary date and interval

        static let sequentialDefault = TimeStrategy.sequential(interval: 1)
        static let reverseDefault = TimeStrategy.reverse(interval: 1)
    }

    func createMessageWithIndex(
        index: Int,
        message: String? = nil,
        baseDate: Date,
        timeStrategy: TimeStrategy,
        completion: ((Int, Date) -> Void)?
    ) {
        let timestamp: Date

        switch timeStrategy {
        case .none:
            timestamp = baseDate
        case .sequential(let interval):
            timestamp = baseDate.addingTimeInterval(Double(index) * interval)
        case .reverse(let interval):
            timestamp = baseDate.addingTimeInterval(Double(index) * -interval)
        case .custom(let date, let interval):
            timestamp = date.addingTimeInterval(Double(index) * interval)
        }

        let message = message ?? "Log: \(index)"
        manager.create(message: message, timestamp: timestamp) {
            completion?(index, timestamp)
        }
    }

    func createRemainingMessages(
        basedOn countOfManuallyCreatedMessages: Int = 0,
        timeStrategy: TimeStrategy = .none,
        completion: ((_ index: Int, _ timestamp: Date) -> Void)? = nil
    ) {
        let remainsBatchSize = batchSizeConstant - countOfManuallyCreatedMessages
        let baseDate = Date()

        for i in 1...remainsBatchSize {
            createMessageWithIndex(index: i,
                                   baseDate: baseDate,
                                   timeStrategy: timeStrategy,
                                   completion: completion)
        }
    }

    func createMessages<R: RangeExpression>(
        message: String? = nil,
        range: R,
        timeStrategy: TimeStrategy = .none,
        completion: ((_ index: Int, _ timestamp: Date) -> Void)? = nil
    ) where R.Bound == Int {
        let baseDate = Date()

        let resolvedRange = range.relative(to: 0..<Int.max)

        for i in resolvedRange {
            createMessageWithIndex(
                index: i,
                message: message,
                baseDate: baseDate,
                timeStrategy: timeStrategy,
                completion: completion
            )
        }
    }
}
