//
//  MBLoggerCoreDataManagerTests.swift
//  MindboxLoggerTests
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Testing
import Foundation
import UIKit
@preconcurrency @testable import MindboxLogger

/// Serialized: several tests post global `UIApplication` background/foreground
/// notifications, which every live `MBLoggerCoreDataManager` instance observes.
/// Under Swift Testing's default parallelism those posts would flip
/// `writesImmediately` on other tests' managers mid-run (XCTest masked this by
/// running a class's methods serially).
@Suite("MBLoggerCoreDataManager", .tags(.storage, .storageState), .serialized)
struct MBLoggerCoreDataManagerTests {

    let manager: MBLoggerCoreDataManager
    let batchSizeConstant: Int

    init() {
        manager = MBLoggerCoreDataManager.makeIsolated()
        MBLoggerCoreDataManager.waitUntilReady(manager)
        try? manager.deleteAll()
        MBLoggerCoreDataManager.drainQueue(manager)
        batchSizeConstant = manager.debugBatchSize
    }

    // MARK: - CRUD

    @Test("A full batch is flushed and queryable by period")
    func createWithBatch() async throws {
        let message = "Test message"
        let timestamp = Date()

        await create(manager, message: message, timestamp: timestamp)
        // Fill the rest of the batch with far-future timestamps so only the first is in range.
        let base = Date()
        for index in 1..<batchSizeConstant {
            await create(manager, message: "Log: \(index)",
                         timestamp: base.addingTimeInterval(Double(index) * 10))
        }

        let result = try manager.fetchPeriod(timestamp, timestamp)
        #expect(result.count == 1)
        #expect(result.first?.message == message)
        #expect(result.first?.timestamp == timestamp)
    }

    @Test("getFirstLog returns the oldest record")
    func fetchFirstLog() async throws {
        let t1 = Date().addingTimeInterval(-60)
        let t2 = Date().addingTimeInterval(-30)
        let t3 = Date()

        await create(manager, message: "Test message 1", timestamp: t1)
        await create(manager, message: "Test message 2", timestamp: t2)
        await create(manager, message: "Test message 3", timestamp: t3)
        await createRemaining(basedOn: 3) // fill to a full batch -> flush

        let first = try manager.getFirstLog()
        #expect(first?.message == "Test message 1")
        #expect(first?.timestamp == t1)
    }

    @Test("getLastLog returns the newest record")
    func fetchLastLog() async throws {
        let t1 = Date().addingTimeInterval(-60)
        let t2 = Date().addingTimeInterval(-30)
        let t3 = Date()

        await create(manager, message: "Test message 1", timestamp: t1)
        await create(manager, message: "Test message 2", timestamp: t2)
        await createRemaining(basedOn: 3, strategy: .reverseDefault)
        await create(manager, message: "Test message 3", timestamp: t3)

        let last = try manager.getLastLog()
        #expect(last?.message == "Test message 3")
        #expect(last?.timestamp == t3)
    }

    @Test("fetchPeriod returns the records inside the window, sorted ascending")
    func fetchPeriod() async throws {
        let t1 = Date().addingTimeInterval(-60)
        let t2 = Date().addingTimeInterval(-30)
        let t3 = Date()

        await createRemaining(strategy: .reverse(interval: 100)) // far in the past
        await create(manager, message: "Test message 1", timestamp: t1)
        await create(manager, message: "Test message 2", timestamp: t2)
        await create(manager, message: "Test message 3", timestamp: t3)
        await createRemaining(basedOn: 3, strategy: .sequentialDefault) // near future

        let result = try manager.fetchPeriod(t1, t2)
        #expect(result.count == 2)
        #expect(result[0].message == "Test message 1")
        #expect(result[0].timestamp == t1)
        #expect(result[1].message == "Test message 2")
        #expect(result[1].timestamp == t2)
    }

    // MARK: - Background / foreground state

    @Test("didEnterBackground turns on immediate writes (background task is .invalid in tests)")
    func enterBackgroundEnablesImmediateWrite() async {
        #expect(await onQueue { self.manager.debugWritesImmediately } == false)

        await createMessages(range: 1...(batchSizeConstant / 2), strategy: .sequentialDefault)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        #expect(await onQueue { self.manager.debugWritesImmediately } == true)
    }

    @Test("flushBufferInBackground persists the buffer and enables immediate writes")
    func flushBufferInBackground() async throws {
        #expect(await onQueue { self.manager.debugWritesImmediately } == false)

        let half = batchSizeConstant / 2
        await createMessages(range: 1...half, strategy: .sequentialDefault)

        manager.debugFlushBufferInBackground()
        await drain(manager)

        let last = try manager.getLastLog()
        #expect(last?.message == "Log: \(half)")
        #expect(await onQueue { self.manager.debugWritesImmediately } == true)
    }

    @Test("The immediate-write flag toggles with background/foreground transitions")
    func flagTogglesOnApplicationStateChanges() async {
        #expect(await onQueue { self.manager.debugWritesImmediately } == false)

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        #expect(await onQueue { self.manager.debugWritesImmediately } == true)

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(await onQueue { self.manager.debugWritesImmediately } == false)

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        #expect(await onQueue { self.manager.debugWritesImmediately } == true)
    }

    @Test("Single-log mode persists each message immediately")
    func singleLogModeWritesEachMessageImmediately() async throws {
        manager.setImmediateWrite(true)
        await drain(manager)

        let count = Int.random(in: 1..<batchSizeConstant)
        let base = Date()
        for index in 1...count {
            let timestamp = base.addingTimeInterval(Double(index))
            await create(manager, message: "Log: \(index)", timestamp: timestamp)
            let last = try manager.getLastLog()
            #expect(last?.timestamp == timestamp)
            #expect(last?.message == "Log: \(index)")
        }

        #expect(try manager.getLastLog()?.message == "Log: \(count)")
        #expect(try manager.fetchPeriod(.distantPast, .distantFuture).count == count)
    }

    // MARK: - Trimming

    @Test("Trim caps at the max fraction when way over the limit", .tags(.trimming))
    func trimCapsAtMaxFractionWhenWayOverLimit() async throws {
        #expect(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)
        await drain(manager)

        let total = 100
        await createMessages(range: 0..<total, strategy: .sequentialDefault)

        manager.debugSerialQueue.async { self.manager.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        await drain(manager)

        let left = try manager.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == total / 2)
        #expect(left.first?.message == "Log: \(total / 2)")
        #expect(left.last?.message == "Log: \(total - 1)")
    }

    @Test("Trim is a no-op at or below the limit", .tags(.trimming))
    func trimNoOperationWhenBelowOrEqualLimit() async throws {
        #expect(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)
        await drain(manager)

        let total = 20
        await createMessages(range: 0..<total, strategy: .sequentialDefault)

        manager.debugSerialQueue.async { self.manager.debugTrimIfNeeded(precomputedSizeKB: 50) }
        await drain(manager)
        #expect(try manager.fetchPeriod(.distantPast, .distantFuture).count == total)

        manager.debugSerialQueue.async { self.manager.debugTrimIfNeeded(precomputedSizeKB: 128) }
        await drain(manager)
        #expect(try manager.fetchPeriod(.distantPast, .distantFuture).count == total)
    }

    @Test("Trim respects the min fraction when slightly over the limit", .tags(.trimming))
    func trimRespectsMinFractionWhenSlightlyOverLimit() async throws {
        #expect(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)
        await drain(manager)

        let total = 100
        await createMessages(range: 0..<total, strategy: .sequentialDefault)

        let fraction = try #require(manager.debugComputeTrimFraction(sizeKB: 129, limitKB: 128))
        try manager.deleteOldestLogs(fraction: fraction)

        let left = try manager.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == 84)
        #expect(left.first?.message == "Log: 16") // deleted 0…15
    }

    @Test("Trim rounds the delete count to the nearest whole record", .tags(.trimming))
    func trimRoundingBehavior() async throws {
        #expect(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)
        await drain(manager)

        await createMessages(range: 0..<3, strategy: .sequentialDefault)

        try manager.deleteOldestLogs(fraction: 1.0 / 3.0) // round(1.0) = 1
        var left = try manager.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == 2)
        #expect(left.first?.message == "Log: 1")

        try manager.deleteOldestLogs(fraction: 2.0 / 3.0) // round(1.333) = 1
        left = try manager.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == 1)
        #expect(left.first?.message == "Log: 2")
    }

    @Test("Trim respects the cooldown between runs", .tags(.trimming))
    func trimRespectsCooldown() async throws {
        let m = MBLoggerCoreDataManager.makeIsolated(config: .default)
        #expect(m.debugIsStoreLoaded)
        m.debugResetCooldown()
        m.setImmediateWrite(true)
        await drain(m)

        let total = 40
        let base = Date()
        for index in 0..<total {
            await create(m, message: "Log: \(index)", timestamp: base.addingTimeInterval(Double(index)))
        }

        // 1st trim: down to 20.
        m.debugSerialQueue.async { m.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        await drain(m)
        var left = try m.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == 20)
        #expect(left.first?.message == "Log: 20")

        // 2nd call under cooldown — no change.
        m.debugSerialQueue.async { m.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        await drain(m)
        left = try m.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == 20)

        // Reset the cooldown and trim again — down to 10.
        m.debugResetCooldown()
        m.debugSerialQueue.async { m.debugTrimIfNeeded(precomputedSizeKB: Int.max) }
        await drain(m)
        left = try m.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == 10)
        #expect(left.first?.message == "Log: 30")
    }

    @Test("Trim deletes the oldest records first", .tags(.trimming))
    func trimDeletesOldestFirst() async throws {
        #expect(manager.debugIsStoreLoaded)
        manager.debugResetCooldown()
        manager.setImmediateWrite(true)
        await drain(manager)

        let base = Date()
        for index in 0..<5 {
            await create(manager, message: "OLD\(index)", timestamp: base.addingTimeInterval(Double(index)))
        }
        for index in 0..<5 {
            await create(manager, message: "NEW\(index)", timestamp: base.addingTimeInterval(Double(100 + index)))
        }

        try manager.deleteOldestLogs(fraction: 0.5)
        let left = try manager.fetchPeriod(.distantPast, .distantFuture)
        #expect(left.count == 5)
        #expect(left.allSatisfy { $0.message.hasPrefix("NEW") })
    }

    @Test("The write counter resets after the configured number of writes", .tags(.trimming))
    func writeCounter() async {
        let perTrim = manager.debugLimitTheNumberOfOperationsBeforeCheckingIfDeletionIsRequired
        let logsToCreate = batchSizeConstant * perTrim - 1

        await createMessages(range: 1...logsToCreate, strategy: .sequentialDefault)
        #expect(await onQueue { self.manager.debugWriteCount } == perTrim - 1)

        await create(manager, message: "Log: 0", timestamp: Date())
        #expect(await onQueue { self.manager.debugWriteCount } == 0)
    }

    // MARK: - Bootstrap

    @Test("Bootstrap enables storage and sets the context flags")
    func bootstrapEnabledSetsContextFlags() {
        let m = MBLoggerCoreDataManager.makeIsolated()
        MBLoggerCoreDataManager.waitUntilReady(m)

        #expect(m.storageState == .enabled)
        #expect(m.debugHasPersistentStore)
        #expect(m.debugContext != nil)
        #expect(m.debugIsStoreLoaded)
        #expect(m.debugLogBufferCapacity >= m.debugBatchSize)
    }

    @Test("Bootstrap disables storage when the loader fails")
    func bootstrapDisabledWhenLoaderFails() {
        let failing = MBLoggerCoreDataManager(debug: true, config: .default, loader: AlwaysFailLoader())
        MBLoggerCoreDataManager.waitUntilReady(failing)

        #expect(failing.storageState == .disabled)
        #expect(failing.debugHasPersistentStore == false)
        #expect(failing.debugContext == nil)
        #expect(failing.debugIsStoreLoaded == false)
    }
}

// MARK: - Async helpers

private extension MBLoggerCoreDataManagerTests {

    enum TimeStrategy {
        case none
        case sequential(interval: TimeInterval)
        case reverse(interval: TimeInterval)

        static let sequentialDefault = TimeStrategy.sequential(interval: 1)
        static let reverseDefault = TimeStrategy.reverse(interval: 1)

        func timestamp(baseDate: Date, index: Int) -> Date {
            switch self {
            case .none: return baseDate
            case .sequential(let interval): return baseDate.addingTimeInterval(Double(index) * interval)
            case .reverse(let interval): return baseDate.addingTimeInterval(Double(index) * -interval)
            }
        }
    }

    /// Awaits a single `create` completion.
    func create(_ m: MBLoggerCoreDataManager, message: String, timestamp: Date) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            m.create(message: message, timestamp: timestamp) { continuation.resume() }
        }
    }

    /// Awaits the manager's serial queue draining.
    func drain(_ m: MBLoggerCoreDataManager) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            m.debugSerialQueue.async { continuation.resume() }
        }
    }

    /// Reads a value on the manager's serial queue (matches the production access pattern).
    func onQueue<T>(_ body: @escaping () -> T) async -> T {
        await withCheckedContinuation { (continuation: CheckedContinuation<T, Never>) in
            manager.debugSerialQueue.async { continuation.resume(returning: body()) }
        }
    }

    func createMessages<R: RangeExpression>(range: R, strategy: TimeStrategy = .none) async where R.Bound == Int {
        let baseDate = Date()
        for index in range.relative(to: 0..<Int.max) {
            await create(manager, message: "Log: \(index)", timestamp: strategy.timestamp(baseDate: baseDate, index: index))
        }
    }

    func createRemaining(basedOn manual: Int = 0, strategy: TimeStrategy = .none) async {
        let baseDate = Date()
        for index in 1...(batchSizeConstant - manual) {
            await create(manager, message: "Log: \(index)", timestamp: strategy.timestamp(baseDate: baseDate, index: index))
        }
    }
}
