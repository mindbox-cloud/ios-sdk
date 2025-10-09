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

    private var batchSizeConstant: Int!
    var manager: MBLoggerCoreDataManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        manager = MBLoggerCoreDataManager.makeIsolated()
        MBLoggerCoreDataManager.waitUntilReady(manager)

        try? manager.deleteAll()
        MBLoggerCoreDataManager.drainQueue(manager)

        batchSizeConstant = manager.debugBatchSize
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func test_measure_create_one_batch() throws {
        measure {
            let exp = expectation(description: "Fetch created log")
            exp.expectedFulfillmentCount = batchSizeConstant
            createMessages(range: 1...batchSizeConstant) { _, _ in exp.fulfill() }
            wait(for: [exp])
        }
    }

    func test_measure_create_1_000() throws {
        let logsCount = 1_000
        measure {
            let exp = expectation(description: "Fetch created log")
            exp.expectedFulfillmentCount = logsCount
            createMessages(range: 0..<logsCount, timeStrategy: .sequentialDefault) { _, _ in exp.fulfill() }
            wait(for: [exp])
        }
    }

    func testCreateWithBatch() throws {
        let manual = 1
        let exp = expectation(description: "Fetch created log")
        exp.expectedFulfillmentCount = batchSizeConstant

        let message = "Test message"
        let timestamp = Date()
        manager.create(message: message, timestamp: timestamp) { exp.fulfill() }

        createRemainingMessages(basedOn: manual, timeStrategy: .sequential(interval: 10)) { _, _ in exp.fulfill() }
        wait(for: [exp])

        let check = expectation(description: "Fetch period logs")
        manager.debugSerialQueue.async {
            do {
                let r = try self.manager.fetchPeriod(timestamp, timestamp)
                XCTAssertEqual(r.count, 1)
                XCTAssertEqual(r.first?.message, message)
                XCTAssertEqual(r.first?.timestamp, timestamp)
                check.fulfill()
            } catch {}
        }
        wait(for: [check])
    }

    func testFetchFirstLog() throws {
        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let t1 = Date().addingTimeInterval(-60)
        let t2 = Date().addingTimeInterval(-30)
        let t3 = Date()

        let exp = expectation(description: "created")
        exp.expectedFulfillmentCount = batchSizeConstant

        manager.create(message: message1, timestamp: t1) { exp.fulfill() }
        manager.create(message: message2, timestamp: t2) { exp.fulfill() }
        manager.create(message: message3, timestamp: t3) { exp.fulfill() }
        createRemainingMessages(basedOn: 3) { _, _ in exp.fulfill() }
        wait(for: [exp])

        let first = try manager.getFirstLog()
        XCTAssertEqual(first?.message, message1)
        XCTAssertEqual(first?.timestamp, t1)
    }

    func testFetchLastLog() throws {
        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let t1 = Date().addingTimeInterval(-60)
        let t2 = Date().addingTimeInterval(-30)
        let t3 = Date()

        let exp = expectation(description: "created")
        exp.expectedFulfillmentCount = batchSizeConstant

        manager.create(message: message1, timestamp: t1) { exp.fulfill() }
        manager.create(message: message2, timestamp: t2) { exp.fulfill() }
        createRemainingMessages(basedOn: 3, timeStrategy: .reverseDefault) { _, _ in exp.fulfill() }
        manager.create(message: message3, timestamp: t3) { exp.fulfill() }
        wait(for: [exp])

        let last = try manager.getLastLog()
        XCTAssertEqual(last?.message, message3)
        XCTAssertEqual(last?.timestamp, t3)
    }

    func testFetchPeriod() throws {
        let message1 = "Test message 1"
        let message2 = "Test message 2"
        let message3 = "Test message 3"
        let t1 = Date().addingTimeInterval(-60)
        let t2 = Date().addingTimeInterval(-30)
        let t3 = Date()

        let exp = expectation(description: "created")
        exp.expectedFulfillmentCount = batchSizeConstant * 2

        createRemainingMessages(timeStrategy: .reverse(interval: 100)) { _, _ in exp.fulfill() }
        manager.create(message: message1, timestamp: t1) { exp.fulfill() }
        manager.create(message: message2, timestamp: t2) { exp.fulfill() }
        manager.create(message: message3, timestamp: t3) { exp.fulfill() }
        createRemainingMessages(basedOn: 3, timeStrategy: .sequentialDefault) { _, _ in exp.fulfill() }
        wait(for: [exp])

        let r = try manager.fetchPeriod(t1, t2)
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[0].message, message1)
        XCTAssertEqual(r[0].timestamp, t1)
        XCTAssertEqual(r[1].message, message2)
        XCTAssertEqual(r[1].timestamp, t2)
    }

    func testFlushBufferWhenApplicationDidEnterBackgroundReturnsInvalidInTestsAndChangesAppState() throws {
        XCTAssertFalse(manager.debugWritesImmediately)

        let half = expectation(description: "half-batch")
        half.expectedFulfillmentCount = batchSizeConstant / 2
        createMessages(range: 1...batchSizeConstant/2, timeStrategy: .sequentialDefault) { _, _ in
            half.fulfill()
        }
        wait(for: [half])

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        let check = expectation(description: "writesImmediately true")
        manager.debugSerialQueue.async {
            XCTAssertTrue(self.manager.debugWritesImmediately)
            check.fulfill()
        }
        wait(for: [check])
    }

    func testFlushBufferInBackground() throws {
        XCTAssertFalse(manager.debugWritesImmediately)

        let half = expectation(description: "half-batch")
        half.expectedFulfillmentCount = batchSizeConstant / 2
        createMessages(range: 1...batchSizeConstant/2, timeStrategy: .sequentialDefault) { _, _ in
            half.fulfill()
        }
        wait(for: [half])

        manager.debugFlushBufferInBackground()

        let check = expectation(description: "flushed")
        manager.debugSerialQueue.async {
            do {
                let last = try self.manager.getLastLog()
                XCTAssertEqual(last?.message, "Log: \(self.batchSizeConstant/2)")
                XCTAssertTrue(self.manager.debugWritesImmediately)
                check.fulfill()
            } catch {}
        }
        wait(for: [check])
    }

    func testFlagTogglesOnApplicationStateChanges() throws {
        let toggle = expectation(description: "Flag toggled 3 times")
        toggle.expectedFulfillmentCount = 3

        XCTAssertFalse(manager.debugWritesImmediately)

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        manager.debugSerialQueue.async {
            XCTAssertTrue(self.manager.debugWritesImmediately)
            toggle.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        manager.debugSerialQueue.async {
            XCTAssertFalse(self.manager.debugWritesImmediately)
            toggle.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        manager.debugSerialQueue.async {
            XCTAssertTrue(self.manager.debugWritesImmediately)
            toggle.fulfill()
        }

        wait(for: [toggle])
    }

    func testSingleLogModeWritesEachMessageImmediately() throws {
        manager.setImmediateWrite(true)

        let maxCountOfLogs = Int.random(in: 1..<batchSizeConstant)
        let exp = expectation(description: "created")
        exp.expectedFulfillmentCount = maxCountOfLogs

        createMessages(range: 1...maxCountOfLogs, timeStrategy: .sequentialDefault) { index, ts in
            let last = try? self.manager.getLastLog()
            XCTAssertEqual(last?.timestamp, ts)
            XCTAssertEqual(last?.message, "Log: \(index)")
            exp.fulfill()
        }
        wait(for: [exp])

        let last = try manager.getLastLog()
        XCTAssertEqual(last?.message, "Log: \(maxCountOfLogs)")

        let all = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(all.count, maxCountOfLogs)
    }

    func testTrim_CapsAtMaxFraction_WhenWayOverLimit() throws {
        XCTAssertTrue(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)

        let total = 100
        let created = expectation(description: "created"); created.expectedFulfillmentCount = total
        createMessages(range: 0..<total, timeStrategy: .sequentialDefault) { _, _ in created.fulfill() }
        wait(for: [created]); MBLoggerCoreDataManager.drainQueue(manager)

        manager.debugSerialQueue.async { self.manager.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        MBLoggerCoreDataManager.drainQueue(manager)

        let left = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, total/2)
        XCTAssertEqual(left.first?.message, "Log: \(total/2)")
        XCTAssertEqual(left.last?.message, "Log: \(total-1)")
    }

    func testTrim_NoOperation_WhenBelowOrEqualLimit() throws {
        XCTAssertTrue(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)

        let total = 20
        let created = expectation(description: "created"); created.expectedFulfillmentCount = total
        createMessages(range: 0..<total, timeStrategy: .sequentialDefault) { _, _ in created.fulfill() }
        wait(for: [created]); MBLoggerCoreDataManager.drainQueue(manager)

        manager.debugSerialQueue.async { self.manager.debugTrimIfNeeded(precomputedSizeKB: 50) }
        MBLoggerCoreDataManager.drainQueue(manager)
        var left = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, total)

        manager.debugSerialQueue.async { self.manager.debugTrimIfNeeded(precomputedSizeKB: 128) }
        MBLoggerCoreDataManager.drainQueue(manager)
        left = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, total)
    }

    func testTrim_RespectsMinFraction_WhenSlightlyOverLimit() throws {
        XCTAssertTrue(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)

        let total = 100
        let created = expectation(description: "created"); created.expectedFulfillmentCount = total
        createMessages(range: 0..<total, timeStrategy: .sequentialDefault) { _, _ in created.fulfill() }
        wait(for: [created]); MBLoggerCoreDataManager.drainQueue(manager)

        let limitKB = 128
        let sizeKB  = 129
        guard let fraction = manager.debugComputeTrimFraction(sizeKB: sizeKB, limitKB: limitKB) else {
            return XCTFail("fraction must be computed")
        }
        try manager.deleteOldestLogs(fraction: fraction)

        let left = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, 84)
        XCTAssertEqual(left.first?.message, "Log: 16") // deleted 0…15
    }

    func testTrim_RoundingBehavior() throws {
        XCTAssertTrue(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)

        let total = 3
        let created = expectation(description: "created"); created.expectedFulfillmentCount = total
        createMessages(range: 0..<total, timeStrategy: .sequentialDefault) { _, _ in created.fulfill() }
        wait(for: [created]); MBLoggerCoreDataManager.drainQueue(manager)

        try manager.deleteOldestLogs(fraction: 1.0/3.0) // round(1) = 1
        var left = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, 2)
        XCTAssertEqual(left.first?.message, "Log: 1")

        try manager.deleteOldestLogs(fraction: 2.0/3.0) // 2 → round(1.333) = 1
        left = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, 1)
        XCTAssertEqual(left.first?.message, "Log: 2")
    }

    func testTrim_RespectsCooldown() throws {
        let m = MBLoggerCoreDataManager.makeIsolated(config: .default)

        XCTAssertTrue(m.debugIsStoreLoaded)
        m.debugResetCooldown()
        m.setImmediateWrite(true)

        let total = 40
        let created = expectation(description: "created")
        created.expectedFulfillmentCount = total

        let base = Date()
        for i in 0..<total {
            m.create(message: "Log: \(i)", timestamp: base.addingTimeInterval(Double(i))) {
                created.fulfill()
            }
        }
        wait(for: [created])
        MBLoggerCoreDataManager.drainQueue(m)

        // 1st trim: trim to 20
        m.debugSerialQueue.async { m.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        MBLoggerCoreDataManager.drainQueue(m)
        var left = try m.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, 20)
        XCTAssertEqual(left.first?.message, "Log: 20")

        // 2nd call under cooldown — no changes
        m.debugSerialQueue.async { m.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        MBLoggerCoreDataManager.drainQueue(m)
        left = try m.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, 20)

        // Reset the cooldown and trim again — up to 10
        m.debugResetCooldown()
        m.debugSerialQueue.async { m.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        MBLoggerCoreDataManager.drainQueue(m)
        left = try m.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, 10)
        XCTAssertEqual(left.first?.message, "Log: 30")
    }

    func testTrim_DeletesOldestFirst() throws {
        XCTAssertTrue(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)

        let base = Date()
        for i in 0..<5 { manager.create(message: "OLD\(i)", timestamp: base.addingTimeInterval(Double(i))) {} }
        for i in 0..<5 { manager.create(message: "NEW\(i)", timestamp: base.addingTimeInterval(Double(100+i))) {} }
        MBLoggerCoreDataManager.drainQueue(manager)

        try manager.deleteOldestLogs(fraction: 0.5)
        let left = try manager.fetchPeriod(.distantPast, .distantFuture)
        XCTAssertEqual(left.count, 5)
        XCTAssertTrue(left.allSatisfy { $0.message.hasPrefix("NEW") })
    }

    func testWriteCounter() throws {
        let logsToCreate = batchSizeConstant * manager.debugLimitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired - 1
        let created = expectation(description: "created all"); created.expectedFulfillmentCount = logsToCreate
        createMessages(range: 1...logsToCreate, timeStrategy: .sequentialDefault) { _, _ in created.fulfill() }
        wait(for: [created])

        let drained = expectation(description: "queue drained")
        manager.debugSerialQueue.async { drained.fulfill() }
        wait(for: [drained])

        XCTAssertEqual(manager.debugWriteCount,
                       manager.debugLimitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired - 1)

        let lastOne = expectation(description: "last")
        createMessageWithIndex(index: 0, baseDate: Date(), timeStrategy: .sequentialDefault) { _, _ in lastOne.fulfill() }
        wait(for: [lastOne])

        XCTAssertEqual(manager.debugWriteCount, 0)
    }

    func testBootstrap_Enabled_SetsContextFlags_andIsWritableTrue() {
        let m = MBLoggerCoreDataManager.makeIsolated()
        MBLoggerCoreDataManager.waitUntilReady(m)

        XCTAssertEqual(m.storageState, .enabled)
        XCTAssertTrue(m.debugHasPersistentStore)
        XCTAssertNotNil(m.debugContext)
        XCTAssertTrue(m.debugIsStoreLoaded)
        XCTAssertGreaterThanOrEqual(m.debugLogBufferCapacity, m.debugBatchSize)
    }

    func testBootstrap_Disabled_WhenLoaderFails() {
        let failing = MBLoggerCoreDataManager(debug: true, config: .default, loader: AlwaysFailLoader())
        MBLoggerCoreDataManager.waitUntilReady(failing)

        XCTAssertEqual(failing.storageState, .disabled)
        XCTAssertFalse(failing.debugHasPersistentStore)
        XCTAssertNil(failing.debugContext)
        XCTAssertFalse(failing.debugIsStoreLoaded)
    }
}

// MARK: - Helpers

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
