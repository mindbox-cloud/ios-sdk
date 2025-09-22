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

    private func makeLoader(dbName: String = "TestDB") throws -> (loader: DatabaseLoading, url: URL) {
        let url = tempDir.appendingPathComponent("\(dbName).sqlite")
        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        let loader = try DatabaseLoader(persistentStoreDescriptions: [desc], applicationGroupIdentifier: nil)
        return (loader, url)
    }

    // MARK: - Tests

    func test_LoadsOnDiskStore_Succeeds() throws {
        let (loader, url) = try makeLoader()
        let container = try loader.loadPersistentContainer()

        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first)
        XCTAssertEqual(store.type, NSSQLiteStoreType)
        XCTAssertTrue(fm.fileExists(atPath: url.path))
    }

    func test_Destroy_DetachesStore_AndRecreateChangesStoreUUID() throws {
        let (loader, url) = try makeLoader()
        let container = try loader.loadPersistentContainer()
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first)

        // UUID до destroy
        let uuidBefore = psc.metadata(for: store)[NSStoreUUIDKey] as? String

        // Уничтожаем
        try loader.destroy()

        // Стор отвязан от координатора
        XCTAssertNil(psc.persistentStore(for: url), "Store should be detached after destroy")

        // Перезагружаем — должен появиться новый стор
        let container2 = try loader.loadPersistentContainer()
        let psc2 = container2.persistentStoreCoordinator
        let store2 = try XCTUnwrap(psc2.persistentStores.first)

        let uuidAfter = psc2.metadata(for: store2)[NSStoreUUIDKey] as? String
        XCTAssertNotEqual(uuidBefore, uuidAfter, "Store UUID should change after destroy+recreate")
    }

    func test_Destroy_UsesDescriptionURL_WhenStoreNotLoaded() throws {
        // Создаём мусорный файл по ожидаемому пути, не загружая стор
        let (loader, url) = try makeLoader(dbName: "Precreated")
        try "garbage".data(using: .utf8)!.write(to: url)
        XCTAssertTrue(fm.fileExists(atPath: url.path))

        // destroy должен расчистить путь так, чтобы затем можно было поднять базу
        try loader.destroy()

        // Если файл физически остался — это ок; главное, что база загружается
        let container = try loader.loadPersistentContainer()
        let psc = container.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first)
        XCTAssertEqual(store.type, NSSQLiteStoreType)
    }

    func test_LoadPersistentContainer_RetryAfterDestroy_OnCorruptedFile() throws {
        let (loader, url) = try makeLoader(dbName: "Corrupted")
        try "not a sqlite database".data(using: .utf8)!.write(to: url)

        let container = try loader.loadPersistentContainer()

        let psc = container.persistentStoreCoordinator
        let store = psc.persistentStores.first
        XCTAssertNotNil(store)
        XCTAssertEqual(store?.type, NSSQLiteStoreType)
        XCTAssertTrue(fm.fileExists(atPath: url.path))
    }

    func test_MakeInMemoryContainer_ReturnsInMemoryStore() throws {
        let (loader, _) = try makeLoader(dbName: "InMemoryOnly")
        let mem = try loader.makeInMemoryContainer()

        let psc = mem.persistentStoreCoordinator
        let store = try XCTUnwrap(psc.persistentStores.first)
        XCTAssertEqual(store.type, NSInMemoryStoreType)

        // На iOS URL in-memory стора может быть nil или file:///dev/null
        let urlString = store.url?.absoluteString
        XCTAssertTrue(urlString == nil || urlString == "file:///dev/null",
                      "In-memory URL should be nil or /dev/null, got: \(urlString ?? "nil")")
    }
}

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
        XCTAssertThrowsError(try loader.loadPersistentContainer())
    }

    func test_makeInMemoryContainer_throws() {
        XCTAssertThrowsError(try loader.makeInMemoryContainer())
    }

    func test_destroy_doesNotThrow() {
        XCTAssertNoThrow(try loader.destroy())
    }
}
