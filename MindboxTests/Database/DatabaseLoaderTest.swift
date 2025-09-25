//
//  DatabaseLoaderTest.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 07.04.2021.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
import CoreData
@testable import Mindbox

final class DataBaseLoaderTests: XCTestCase {

    private var tempDir: URL!
    private let fm = FileManager.default

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        tempDir = base.appendingPathComponent("MindboxDBTests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? fm.removeItem(at: tempDir) }
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeLoader(dbName: String = "TestDB") throws -> (loader: DatabaseLoader, url: URL) {
        let url = tempDir.appendingPathComponent("\(dbName).sqlite")
        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        let loader = try DatabaseLoader(persistentStoreDescriptions: [desc], applicationGroupIdentifier: nil)
        return (loader, url)
    }

    // MARK: - Existing flow tests

    func test_LoadsOnDiskStore_Succeeds() throws {
        let (loader, url) = try makeLoader()
        let container = try loader.loadPersistentContainer()

        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first, "Persistent store should be loaded")
        XCTAssertEqual(store.type, NSSQLiteStoreType, "Store type must be SQLite")
        XCTAssertTrue(fm.fileExists(atPath: url.path), "SQLite file must exist on disk")
    }

    func test_Destroy_DetachesStore_AndRecreateChangesStoreUUID() throws {
        let (loader, url) = try makeLoader()
        let container = try loader.loadPersistentContainer()
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first, "Store should be present before destroy")

        // UUID before destroy
        let uuidBefore = psc.metadata(for: store)[NSStoreUUIDKey] as? String

        // Destroy
        try loader.destroy()

        // Store is detached from coordinator
        XCTAssertNil(psc.persistentStore(for: url), "Store should be detached after destroy")

        // Recreate
        let container2 = try loader.loadPersistentContainer()
        let psc2 = container2.persistentStoreCoordinator
        let store2 = try XCTUnwrap(psc2.persistentStores.first, "Store should be recreated after destroy")
        let uuidAfter = psc2.metadata(for: store2)[NSStoreUUIDKey] as? String
        XCTAssertNotEqual(uuidBefore, uuidAfter, "Store UUID should change after destroy+recreate")
    }

    func test_Destroy_UsesDescriptionURL_WhenStoreNotLoaded() throws {
        // Pre-create a garbage file at the expected URL without loading the store
        let (loader, url) = try makeLoader(dbName: "Precreated")
        try "garbage".data(using: .utf8)!.write(to: url)
        XCTAssertTrue(fm.fileExists(atPath: url.path), "Precreated file must exist")

        // Destroy should clear path so we can load a fresh store afterwards
        try loader.destroy()

        // The physical file may or may not remain; critical point is that a store loads fine
        let container = try loader.loadPersistentContainer()
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first, "Store should load after destroy using description URL")
        XCTAssertEqual(store.type, NSSQLiteStoreType, "Store type must be SQLite")
    }

    func test_LoadPersistentContainer_RetryAfterDestroy_OnCorruptedFile() throws {
        let (loader, url) = try makeLoader(dbName: "Corrupted")
        try "not a sqlite database".data(using: .utf8)!.write(to: url)

        let container = try loader.loadPersistentContainer()

        let psc = container.persistentStoreCoordinator
        let store = psc.persistentStores.first
        XCTAssertNotNil(store, "Store should be available after repair retry")
        XCTAssertEqual(store?.type, NSSQLiteStoreType, "Store type must be SQLite after repair")
        XCTAssertTrue(fm.fileExists(atPath: url.path), "SQLite file must exist after repair")
    }

    func test_MakeInMemoryContainer_ReturnsInMemoryStore() throws {
        let (loader, _) = try makeLoader(dbName: "InMemoryOnly")
        let mem = try loader.makeInMemoryContainer()

        let psc = mem.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first, "In-memory store should be present")
        XCTAssertEqual(store.type, NSInMemoryStoreType, "Store type must be in-memory")

        // On iOS URL may be nil or /dev/null for in-memory store
        let urlString = store.url?.absoluteString
        XCTAssertTrue(urlString == nil || urlString == "file:///dev/null",
                      "In-memory URL should be nil or /dev/null, got: \(urlString ?? "nil")")
    }
}

// MARK: - Stub contract tests

final class DataBaseLoading_StubLoaderContractTests: XCTestCase {

    private var loader: DatabaseLoading!

    override func setUp() {
        super.setUp()
        loader = StubLoader()
    }

    override func tearDown() {
        loader = nil
        super.tearDown()
    }

    func test_loadPersistentContainer_throws() {
        XCTAssertThrowsError(try loader.loadPersistentContainer(), "StubLoader must throw on loadPersistentContainer()")
    }

    func test_makeInMemoryContainer_throws() {
        XCTAssertThrowsError(try loader.makeInMemoryContainer(), "StubLoader must throw on makeInMemoryContainer()")
    }

    func test_destroy_doesNotThrow() {
        XCTAssertNoThrow(try loader.destroy(), "StubLoader destroy() must not throw")
    }
}
