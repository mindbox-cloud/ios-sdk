//
//  IsolatedMBLoggerCoreDataManager.swift
//  MindboxTests
//
//  Created by Sergei Semko on 7/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData
import XCTest
@testable import MindboxLogger

#if DEBUG
extension LoggerDBConfig {
    public static let tests = LoggerDBConfig(
        dbSizeLimitKB: 128,
        lowWaterRatio: 0.85,
        minDeleteFraction: 0.05,
        maxDeleteFraction: 0.50,
        batchSize: 15,
        writesPerTrimCheck: 5,
        trimCooldownSec: 0
    )
}


extension MBLoggerCoreDataManager {
    static func makeIsolated(
        config: LoggerDBConfig = .tests,
        filePrefix: String = "MindboxLogger-Tests"
    ) -> MBLoggerCoreDataManager {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(filePrefix)-\(UUID().uuidString).sqlite")

        let description = NSPersistentStoreDescription(url: tempURL)
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        description.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        let loader = LoggerDatabaseLoader(.init(
            modelName: "CDLogMessage",
            applicationGroupId: nil,
            storeURL: tempURL,
            descriptions: [description]
        ))

        let manager = MBLoggerCoreDataManager(debug: true, config: config, loader: loader)
        waitUntilReady(manager)
        drainQueue(manager)
        manager.debugResetCooldown()
        manager.debugResetWriteCount()
        return manager
    }

    /// Waiting for bootstrap to finish (storageState != .initializing)
    @discardableResult
    static func waitUntilReady(_ m: MBLoggerCoreDataManager, timeout: TimeInterval = 5) -> XCTWaiter.Result {
        let exp = XCTestExpectation(description: "MBLogger ready/disabled")
        func tick() {
            if m.storageState != .initializing { exp.fulfill() }
            else { DispatchQueue.global().asyncAfter(deadline: .now() + 0.05, execute: tick) }
        }
        tick()
        return XCTWaiter.wait(for: [exp], timeout: timeout)
    }

    /// Wait for the manager's serial queue to be cleared
    @discardableResult
    static func drainQueue(_ m: MBLoggerCoreDataManager, timeout: TimeInterval = 2) -> XCTWaiter.Result {
        let exp = XCTestExpectation(description: "drain queue")
        m.debugSerialQueue.async { exp.fulfill() }
        return XCTWaiter.wait(for: [exp], timeout: timeout)
    }
}
#endif


