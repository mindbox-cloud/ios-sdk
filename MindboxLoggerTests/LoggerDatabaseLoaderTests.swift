//
//  LoggerDatabaseLoaderTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/12/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
import CoreData
@testable import MindboxLogger

@available(iOS 15.0, *)
final class LoggerDatabaseLoaderTests: XCTestCase {

    // MARK: - Helpers

    private func tmpURL(_ name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MB-Loader-\(name)-\(UUID().uuidString).sqlite")
    }

    private func sqliteHeader(at url: URL) -> String? {
        (try? Data(contentsOf: url).prefix(15)).flatMap { String(data: $0, encoding: .ascii) }
    }

    func test_loadContainer_success_defaultDescription_createsStoreAndContext() throws {
        let url = tmpURL("Success")
        let cfg = LoggerDatabaseLoaderConfig(
            modelName: "CDLogMessage",
            applicationGroupId: nil,
            storeURL: url,
            descriptions: nil
        )
        let loader = LoggerDatabaseLoader(cfg)

        let (container, ctx) = try loader.loadContainer()

        // The file has been created and is valid SQLite.
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(sqliteHeader(at: url), "SQLite format 3")

        // Background context working — trying the simplest recording
        try ctx.performAndWait {
            let entity = NSEntityDescription.entity(forEntityName: "CDLogMessage", in: ctx)!
            let obj = NSManagedObject(entity: entity, insertInto: ctx)
            obj.setValue("test", forKey: "message")
            obj.setValue(Date(), forKey: "timestamp")
            try ctx.save()
        }

        // The container did indeed use defaultDescription(for: url)
        XCTAssertEqual(container.persistentStoreDescriptions.first?.url, url)
        XCTAssertEqual(container.persistentStoreDescriptions.count, 1)
        XCTAssertFalse(container.persistentStoreDescriptions[0].shouldAddStoreAsynchronously)
    }

    func test_loadContainer_autoRecreates_onCorruptedStore() throws {
        let url = tmpURL("Corrupted")

        // We create a “broken” file and sidecars so that the first download fails.
        try "NOT A SQLITE DB".data(using: .utf8)!.write(to: url, options: .atomic)
        try "WAL".data(using: .utf8)!.write(to: URL(fileURLWithPath: url.path + "-wal"))
        try "SHM".data(using: .utf8)!.write(to: URL(fileURLWithPath: url.path + "-shm"))

        let cfg = LoggerDatabaseLoaderConfig(
            modelName: "CDLogMessage",
            applicationGroupId: nil,
            storeURL: url,
            descriptions: nil
        )
        let loader = LoggerDatabaseLoader(cfg)

        // The first loadStores attempt should fail → catch: destroyStore(...) → successful reload
        let (_, ctx) = try loader.loadContainer()

        XCTAssertEqual(sqliteHeader(at: url), "SQLite format 3")

        // And you can write
        try ctx.performAndWait {
            let entity = NSEntityDescription.entity(forEntityName: "CDLogMessage", in: ctx)!
            let obj = NSManagedObject(entity: entity, insertInto: ctx)
            obj.setValue("after-recreate", forKey: "message")
            obj.setValue(Date(), forKey: "timestamp")
            try ctx.save()
        }
    }

    func test_loadContainer_usesExplicitDescriptionURL() throws {
        let url = tmpURL("Explicit")
        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        desc.shouldAddStoreAsynchronously = false

        let cfg = LoggerDatabaseLoaderConfig(
            modelName: "CDLogMessage",
            applicationGroupId: nil,
            storeURL: nil,
            descriptions: [desc]
        )
        let loader = LoggerDatabaseLoader(cfg)

        let (container, _) = try loader.loadContainer()

        XCTAssertEqual(container.persistentStoreDescriptions.count, 1)
        XCTAssertEqual(container.persistentStoreDescriptions.first?.url, url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_loadContainer_throwsWhenModelNotFound() {
        let cfg = LoggerDatabaseLoaderConfig(
            modelName: "ModelThatDoesNotExist",
            applicationGroupId: nil,
            storeURL: nil,
            descriptions: nil
        )
        let loader = LoggerDatabaseLoader(cfg)

        XCTAssertThrowsError(try loader.loadContainer()) { error in
            guard case LoggerDatabaseLoaderError.modelNotFound(let name) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(name, "ModelThatDoesNotExist")
        }
    }

    func test_destroyIfExists_removesStoreAndSidecars() throws {
        let url = tmpURL("DestroyMe")
        let cfg = LoggerDatabaseLoaderConfig(
            modelName: "CDLogMessage",
            applicationGroupId: nil,
            storeURL: url,
            descriptions: nil
        )
        let loader = LoggerDatabaseLoader(cfg)

        // Create a store and immediately release all references (so that the file is not occupied by Core Data).
        try autoreleasepool {
            _ = try loader.loadContainer()
        }

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: url.path))
        _ = fm.createFile(atPath: url.path + "-wal", contents: Data())
        _ = fm.createFile(atPath: url.path + "-shm", contents: Data())

        try loader.destroyIfExists()

        XCTAssertFalse(fm.fileExists(atPath: url.path))
        XCTAssertFalse(fm.fileExists(atPath: url.path + "-wal"))
        XCTAssertFalse(fm.fileExists(atPath: url.path + "-shm"))
    }
}
