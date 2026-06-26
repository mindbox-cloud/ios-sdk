//
//  LoggerDatabaseLoaderTests.swift
//  MindboxLoggerTests
//
//  Created by Sergei Semko on 9/12/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Testing
import Foundation
import CoreData
@testable import MindboxLogger

@Suite("LoggerDatabaseLoader", .tags(.storage, .storageState))
struct LoggerDatabaseLoaderTests {

    // MARK: - Helpers

    private func tmpURL(_ name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MB-Loader-\(name)-\(UUID().uuidString).sqlite")
    }

    private func sqliteHeader(at url: URL) -> String? {
        (try? Data(contentsOf: url).prefix(15)).flatMap { String(data: $0, encoding: .ascii) }
    }

    @available(iOS 15.0, *)
    @Test("Default description: creates a valid SQLite store and a working background context")
    func loadContainerSuccessDefaultDescription() throws {
        let url = tmpURL("Success")
        let cfg = LoggerDatabaseLoaderConfig(modelName: "CDLogMessage", applicationGroupId: nil,
                                             storeURL: url, descriptions: nil)
        let loader = LoggerDatabaseLoader(cfg)

        let (container, ctx) = try loader.loadContainer()

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(sqliteHeader(at: url) == "SQLite format 3")

        try ctx.performAndWait {
            let entity = try #require(NSEntityDescription.entity(forEntityName: "CDLogMessage", in: ctx))
            let obj = NSManagedObject(entity: entity, insertInto: ctx)
            obj.setValue("test", forKey: "message")
            obj.setValue(Date(), forKey: "timestamp")
            try ctx.save()
        }

        #expect(container.persistentStoreDescriptions.first?.url == url)
        #expect(container.persistentStoreDescriptions.count == 1)
        #expect(container.persistentStoreDescriptions[0].shouldAddStoreAsynchronously == false)
    }

    @available(iOS 15.0, *)
    @Test("Auto-recreates the store when the existing file is corrupted")
    func loadContainerAutoRecreatesOnCorruptedStore() throws {
        let url = tmpURL("Corrupted")

        // A broken file + sidecars so the first load attempt fails.
        try "NOT A SQLITE DB".data(using: .utf8)!.write(to: url, options: .atomic)
        try "WAL".data(using: .utf8)!.write(to: URL(fileURLWithPath: url.path + "-wal"))
        try "SHM".data(using: .utf8)!.write(to: URL(fileURLWithPath: url.path + "-shm"))

        let cfg = LoggerDatabaseLoaderConfig(modelName: "CDLogMessage", applicationGroupId: nil,
                                             storeURL: url, descriptions: nil)
        let loader = LoggerDatabaseLoader(cfg)

        // First loadStores fails -> catch destroys the store -> successful reload.
        let (_, ctx) = try loader.loadContainer()
        #expect(sqliteHeader(at: url) == "SQLite format 3")

        try ctx.performAndWait {
            let entity = try #require(NSEntityDescription.entity(forEntityName: "CDLogMessage", in: ctx))
            let obj = NSManagedObject(entity: entity, insertInto: ctx)
            obj.setValue("after-recreate", forKey: "message")
            obj.setValue(Date(), forKey: "timestamp")
            try ctx.save()
        }
    }

    @Test("Honours an explicit store description URL")
    func loadContainerUsesExplicitDescriptionURL() throws {
        let url = tmpURL("Explicit")
        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        desc.shouldAddStoreAsynchronously = false

        let cfg = LoggerDatabaseLoaderConfig(modelName: "CDLogMessage", applicationGroupId: nil,
                                             storeURL: nil, descriptions: [desc])
        let loader = LoggerDatabaseLoader(cfg)

        let (container, _) = try loader.loadContainer()

        #expect(container.persistentStoreDescriptions.count == 1)
        #expect(container.persistentStoreDescriptions.first?.url == url)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Throws .modelNotFound for an unknown model name")
    func loadContainerThrowsWhenModelNotFound() {
        let cfg = LoggerDatabaseLoaderConfig(modelName: "ModelThatDoesNotExist", applicationGroupId: nil,
                                             storeURL: nil, descriptions: nil)
        let loader = LoggerDatabaseLoader(cfg)

        let error = #expect(throws: LoggerDatabaseLoaderError.self) {
            try loader.loadContainer()
        }
        guard case .modelNotFound(let name)? = error else {
            Issue.record("Unexpected error: \(String(describing: error))")
            return
        }
        #expect(name == "ModelThatDoesNotExist")
    }

    @Test("destroyIfExists removes the store and its -wal/-shm sidecars")
    func destroyIfExistsRemovesStoreAndSidecars() throws {
        let url = tmpURL("DestroyMe")
        let cfg = LoggerDatabaseLoaderConfig(modelName: "CDLogMessage", applicationGroupId: nil,
                                             storeURL: url, descriptions: nil)
        let loader = LoggerDatabaseLoader(cfg)

        // Create a store and release all references so the file is not held by Core Data.
        try autoreleasepool {
            _ = try loader.loadContainer()
        }

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: url.path))
        _ = fm.createFile(atPath: url.path + "-wal", contents: Data())
        _ = fm.createFile(atPath: url.path + "-shm", contents: Data())

        try loader.destroyIfExists()

        #expect(fm.fileExists(atPath: url.path) == false)
        #expect(fm.fileExists(atPath: url.path + "-wal") == false)
        #expect(fm.fileExists(atPath: url.path + "-shm") == false)
    }
}
