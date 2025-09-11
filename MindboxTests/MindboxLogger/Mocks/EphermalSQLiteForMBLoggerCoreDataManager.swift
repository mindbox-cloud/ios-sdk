//
//  EphermalSQLiteForMBLoggerCoreDataManager.swift
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
extension MBLoggerCoreDataManager {

    static func makeEphemeralSQLiteContainer() -> MBPersistentContainer {
        let bundle   = Bundle(for: MBLoggerCoreDataManager.self)
        let modelURL = bundle.url(forResource: "CDLogMessage", withExtension: "momd")!
        let model    = NSManagedObjectModel(contentsOf: modelURL)!

        let container = MBPersistentContainer(name: "CDLogMessage",
                                              managedObjectModel: model)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MindboxLogger-Tests-\(UUID().uuidString).sqlite")

        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        desc.shouldAddStoreAsynchronously = false

        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, err in
            precondition(err == nil, "load store failed: \(String(describing: err))")
        }
        return container
    }

    static func makeIsolated() -> MBLoggerCoreDataManager {
        let m = MBLoggerCoreDataManager(debug: true)

        let c = makeEphemeralSQLiteContainer()
        m.debugPersistentContainer = c

        let ctx = c.newBackgroundContext()
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        m.debugContext = ctx

        m.setImmediateWrite(false)
        m.debugResetWriteCount()

        return m
    }

    /// Wait for bootstrap to complete
    static func waitUntilReady(_ m: MBLoggerCoreDataManager, timeout: TimeInterval = 5) {
        let exp = XCTestExpectation(description: "MBLogger ready/disabled")
        func tick() {
            if m.storageState != .initializing { exp.fulfill() }
            else { DispatchQueue.global().asyncAfter(deadline: .now() + 0.05, execute: tick) }
        }
        tick()
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
    }

    /// Wait for the manager's serial queue to drain
    static func drainQueue(_ m: MBLoggerCoreDataManager, timeout: TimeInterval = 2) {
        let exp = XCTestExpectation(description: "drain queue")
        m.debugSerialQueue.async { exp.fulfill() }
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
    }

}
#endif


