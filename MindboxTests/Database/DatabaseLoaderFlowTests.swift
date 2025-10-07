//
//  DatabaseLoaderFlowTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/25/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
import CoreData
@testable import Mindbox

final class DatabaseLoaderFlowTests: XCTestCase {
    
    private typealias MDKey = Constants.StoreMetadataKey

    private var tempDir: URL!
    private let fm = FileManager.default

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        tempDir = base.appendingPathComponent("MindboxDBFlow-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? fm.removeItem(at: tempDir) }
        tempDir = nil
        super.tearDown()
    }

    // Factory to create a loader pointing to a real SQLite URL
    private func makeDescAndURL(dbName: String) -> (NSPersistentStoreDescription, URL) {
        let url = tempDir.appendingPathComponent("\(dbName).sqlite")
        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        return (desc, url)
    }

    // Spy/Stub loader that mirrors real salvage/apply behavior
    final class SpyDatabaseLoader: DatabaseLoader {
        enum LoadMode { case succeed, failAlways, failThenSucceed }

        var stubFreeSize: Int64 = .max
        override var freeSize: Int64 { stubFreeSize }

        var loadMode: LoadMode = .succeed
        private var loadAttempts = 0

        var destroyCallCount = 0
        var shouldDestroyThrow = false

        var salvageCalled = false
        var stubPreserved: [String: Any]? = nil

        var applyCaptured: [String: Any]? = nil

        override func loadPersistentStores() throws -> NSPersistentContainer {
            loadAttempts += 1
            switch loadMode {
            case .succeed:
                return try super.loadPersistentStores()
            case .failAlways:
                throw NSError(domain: NSCocoaErrorDomain, code: 256)
            case .failThenSucceed:
                if loadAttempts == 1 {
                    throw NSError(domain: NSCocoaErrorDomain, code: 256)
                } else {
                    return try super.loadPersistentStores()
                }
            }
        }

        override func destroy() throws {
            destroyCallCount += 1
            if shouldDestroyThrow { throw NSError(domain: "test", code: 1) }
            try super.destroy()
        }

        override func salvageMetadataFromOnDiskStore() -> [String : Any]? {
            salvageCalled = true
            // emulate real filtering by DatabaseLoader.metadataKeysToPreserve
            guard let raw = stubPreserved else { return nil }
            let filtered = raw.filter { Self.metadataKeysToPreserve.contains($0.key) }
            return filtered.isEmpty ? nil : filtered
        }

        override func applyMetadata(_ preserved: [String : Any], to container: NSPersistentContainer) {
            applyCaptured = preserved
            super.applyMetadata(preserved, to: container)
        }
    }

    private func makeSpyLoader(dbName: String = "Flow") throws -> (SpyDatabaseLoader, URL) {
        let (desc, url) = makeDescAndURL(dbName: dbName)
        let loader = try SpyDatabaseLoader(persistentStoreDescriptions: [desc], applicationGroupIdentifier: nil)
        return (loader, url)
    }

    // Helpers to read current store metadata
    private func currentStoreMetadata(on container: NSPersistentContainer) throws -> [String: Any] {
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first, "Expected a persistent store")
        return psc.metadata(for: store)
    }

    // 1) Straight success: no salvage, no destroy
    func test_Flow_StraightSuccess_SkipsRepair() throws {
        let (loader, _) = try makeSpyLoader(dbName: "Straight")
        loader.loadMode = .succeed
        loader.stubPreserved = [
            MDKey.instanceId.rawValue: "should-not-be-used"
        ]

        let container = try loader.loadPersistentContainer()
        let store = try XCTUnwrap(container.persistentStoreCoordinator.persistentStores.first)
        XCTAssertEqual(store.type, NSSQLiteStoreType, "Store must be on-disk SQLite on straight success")
        XCTAssertEqual(loader.destroyCallCount, 0, "destroy must not be called on straight success")
        XCTAssertFalse(loader.salvageCalled, "salvage must not be called on straight success")
        XCTAssertNil(loader.applyCaptured, "applyMetadata must not be called on straight success")
    }

    // 2) Load fails + low disk → in-memory + metadata applied
    func test_Flow_LowDiskSpace_UsesInMemory_AndAppliesMetadata() throws {
        let (loader, _) = try makeSpyLoader(dbName: "LowDisk")
        loader.loadMode = .failAlways
        loader.stubFreeSize = 1 // definitely below threshold

        // Only keys that are actually preserved by DatabaseLoader.metadataKeysToPreserve
        let preserved: [String: Any] = [
            MDKey.infoUpdate.rawValue: 7,
            MDKey.instanceId.rawValue: "im-low-disk"
        ]
        loader.stubPreserved = preserved

        let container = try loader.loadPersistentContainer()
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first)
        XCTAssertEqual(store.type, NSInMemoryStoreType, "Should fall back to in-memory when disk is low")
        XCTAssertEqual(loader.destroyCallCount, 0, "destroy must not be called on low-disk fallback")
        XCTAssertTrue(loader.salvageCalled, "salvage must be called before fallback")
        XCTAssertEqual(loader.applyCaptured?.count, preserved.count, "All preserved keys must be applied")

        let meta = try currentStoreMetadata(on: container)
        for (k, v) in preserved {
            XCTAssertEqual(meta[k] as? NSObject, v as? NSObject, "Preserved metadata '\(k)' must be applied")
        }
    }

    // 3) Load fails + enough disk → destroy+retry succeeds, metadata applied to new on-disk store
    func test_Flow_DestroyAndRetry_Succeeds_AppliesMetadata() throws {
        let (loader, _) = try makeSpyLoader(dbName: "RepairSuccess")
        loader.loadMode = .failThenSucceed
        loader.stubFreeSize = .max // not low

        let preserved: [String: Any] = [
            MDKey.infoUpdate.rawValue: 3,
            MDKey.instanceId.rawValue: "repaired-ok"
        ]
        loader.stubPreserved = preserved

        let container = try loader.loadPersistentContainer()
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first)
        XCTAssertEqual(store.type, NSSQLiteStoreType, "After destroy+retry the store must be on-disk SQLite")
        XCTAssertEqual(loader.destroyCallCount, 1, "destroy must be called exactly once on repair path")
        XCTAssertTrue(loader.salvageCalled, "salvage must be called before repair")
        XCTAssertEqual(loader.applyCaptured?.count, preserved.count, "All preserved keys must be applied after repair")

        let meta = try currentStoreMetadata(on: container)
        for (k, v) in preserved {
            XCTAssertEqual(meta[k] as? NSObject, v as? NSObject, "Repaired store must contain preserved metadata '\(k)'")
        }
    }

    // 4) Repair attempt fails → in-memory fallback (no apply required by current implementation)
    func test_Flow_DestroyAndRetry_Fails_FallsBackToInMemory() throws {
        let (loader, _) = try makeSpyLoader(dbName: "RepairFails")
        loader.loadMode = .failAlways
        loader.stubFreeSize = .max // not low → go to repair path
        loader.stubPreserved = [
            MDKey.instanceId.rawValue: "will-fallback"
        ]
        // If you want to test the branch where destroy throws instead of load failing, uncomment:
        // loader.shouldDestroyThrow = true

        let container = try loader.loadPersistentContainer()
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first)
        XCTAssertEqual(store.type, NSInMemoryStoreType, "Should fall back to in-memory when repair fails")
        XCTAssertGreaterThanOrEqual(loader.destroyCallCount, 1, "destroy should be attempted on repair path")
        XCTAssertTrue(loader.salvageCalled, "salvage must be called on repair path")
        // No strict expectation on apply: current implementation does not re-apply on this branch.
    }
}
