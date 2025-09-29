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

    private enum Constants {
        static let testsFolderPrefix = "MindboxDBTests-"
        static let sqliteExtension = "sqlite"
        static let defaultDatabaseName = "TestDB"
        static let precreatedDatabaseName = "Precreated"
        static let corruptedDatabaseName = "Corrupted"
        static let inMemoryDatabaseName = "InMemoryOnly"

        static let nonSQLitePayload = "not a sqlite database"
        static let garbagePayload = "garbage"
        
        static let devNullURLString = URL(fileURLWithPath: "/dev/null").absoluteString
    }

    private var temporaryDirectoryURL: URL!
    private let fileManager: FileManager = .default

    override func setUp() {
        super.setUp()
        let baseTemporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        temporaryDirectoryURL = baseTemporaryDirectoryURL.appendingPathComponent(
            Constants.testsFolderPrefix + UUID().uuidString,
            isDirectory: true
        )
        try? fileManager.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let temporaryDirectoryURL {
            try? fileManager.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDatabaseLoader(databaseName: String = Constants.defaultDatabaseName)
    throws -> (loader: DatabaseLoader, storeURL: URL) {
        let storeURL = temporaryDirectoryURL.appendingPathComponent("\(databaseName).\(Constants.sqliteExtension)")
        let persistentStoreDescription = NSPersistentStoreDescription(url: storeURL)
        persistentStoreDescription.type = NSSQLiteStoreType
        
        let databaseLoader = try DatabaseLoader(
            persistentStoreDescriptions: [persistentStoreDescription],
            applicationGroupIdentifier: nil
        )
        return (databaseLoader, storeURL)
    }

    // MARK: - Flow tests

    func test_LoadsOnDiskStore_Succeeds() throws {
        let (databaseLoader, storeURL) = try makeDatabaseLoader()
        let persistentContainer = try databaseLoader.loadPersistentContainer()

        let persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        let persistentStore = try XCTUnwrap(
            persistentStoreCoordinator.persistentStores.first,
            "Persistent store should be loaded"
        )
        XCTAssertEqual(persistentStore.type, NSSQLiteStoreType, "Store type must be SQLite")
        XCTAssertTrue(fileManager.fileExists(atPath: storeURL.path), "SQLite file must exist on disk")
    }

    func test_Destroy_DetachesStore_AndRecreateChangesStoreUUID() throws {
        let (databaseLoader, storeURL) = try makeDatabaseLoader()
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        let persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        let persistentStore = try XCTUnwrap(
            persistentStoreCoordinator.persistentStores.first,
            "Store should be present before destroy"
        )

        // UUID before destroy
        let storeUUIDBefore = persistentStoreCoordinator.metadata(for: persistentStore)[NSStoreUUIDKey] as? String

        // Destroy
        try databaseLoader.destroy()

        // Store is detached from coordinator
        XCTAssertNil(
            persistentStoreCoordinator.persistentStore(for: storeURL),
            "Store should be detached after destroy"
        )

        // Recreate
        let recreatedContainer = try databaseLoader.loadPersistentContainer()
        let recreatedCoordinator = recreatedContainer.persistentStoreCoordinator
        let recreatedStore = try XCTUnwrap(
            recreatedCoordinator.persistentStores.first,
            "Store should be recreated after destroy"
        )
        let storeUUIDAfter = recreatedCoordinator.metadata(for: recreatedStore)[NSStoreUUIDKey] as? String
        XCTAssertNotEqual(storeUUIDBefore, storeUUIDAfter, "Store UUID should change after destroy+recreate")
    }

    func test_Destroy_UsesDescriptionURL_WhenStoreNotLoaded() throws {
        // Pre-create a garbage file at the expected URL without loading the store
        let (databaseLoader, storeURL) = try makeDatabaseLoader(databaseName: Constants.precreatedDatabaseName)
        try XCTUnwrap(Constants.garbagePayload.data(using: .utf8)).write(to: storeURL)
        XCTAssertTrue(fileManager.fileExists(atPath: storeURL.path), "Precreated file must exist")

        // Destroy should clear path so we can load a fresh store afterwards
        try databaseLoader.destroy()

        // The physical file may or may not remain; critical point is that a store loads fine
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        let persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        let persistentStore = try XCTUnwrap(
            persistentStoreCoordinator.persistentStores.first,
            "Store should load after destroy using description URL"
        )
        XCTAssertEqual(persistentStore.type, NSSQLiteStoreType, "Store type must be SQLite")
    }

    func test_LoadPersistentContainer_RetryAfterDestroy_OnCorruptedFile() throws {
        let (databaseLoader, storeURL) = try makeDatabaseLoader(databaseName: Constants.corruptedDatabaseName)
        try XCTUnwrap(Constants.nonSQLitePayload.data(using: .utf8)).write(to: storeURL)

        let persistentContainer = try databaseLoader.loadPersistentContainer()
        let persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        let persistentStore = persistentStoreCoordinator.persistentStores.first

        XCTAssertNotNil(persistentStore, "Store should be available after repair retry")
        XCTAssertEqual(persistentStore?.type, NSSQLiteStoreType, "Store type must be SQLite after repair")
        XCTAssertTrue(fileManager.fileExists(atPath: storeURL.path), "SQLite file must exist after repair")
    }

    func test_MakeInMemoryContainer_ReturnsInMemoryStore() throws {
        let (databaseLoader, _) = try makeDatabaseLoader(databaseName: Constants.inMemoryDatabaseName)
        let inMemoryContainer = try databaseLoader.makeInMemoryContainer()

        let persistentStoreCoordinator = inMemoryContainer.persistentStoreCoordinator
        let inMemoryStore = try XCTUnwrap(
            persistentStoreCoordinator.persistentStores.first,
            "In-memory store should be present"
        )
        XCTAssertEqual(inMemoryStore.type, NSInMemoryStoreType, "Store type must be in-memory")

        // On iOS URL may be nil or /dev/null for in-memory store
        let inMemoryURLString = inMemoryStore.url?.absoluteString
        let isNilOrDevNull = (inMemoryURLString == nil ||
                              inMemoryURLString == Constants.devNullURLString)
        XCTAssertTrue(isNilOrDevNull,
                      "In-memory URL should be nil or /dev/null, got: \(inMemoryURLString ?? "nil")")
    }
}
