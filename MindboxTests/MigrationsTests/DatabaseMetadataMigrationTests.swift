//
//  DatabaseMetadataMigrationTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 10/1/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
import CoreData
@testable import Mindbox
@testable import MindboxLogger

final class DatabaseMetadataMigrationTests: XCTestCase {

    private typealias MDKey = Constants.StoreMetadataKey

    private var migration: MigrationProtocol!
    private var storage: PersistenceStorage!

    // MARK: - XCTest lifecycle

    override func setUp() {
        super.setUp()

        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.deviceUUID = "00000000-0000-0000-0000-000000000000"
        storage.installationDate = Date()
        storage.applicationInfoUpdateVersion = nil
        storage.applicationInstanceId = nil

        migration = DatabaseMetadataMigration()
    }

    override func tearDown() {
        migration = nil
        storage = nil

        removeOnDiskStoresIfExist()
        super.tearDown()
    }

    // MARK: - Helpers (disk-based; does not depend on a live repository)

    private func candidateStoreURLs() -> [URL] {
        let fileName = "\(Constants.Database.mombName).sqlite"
        var urls: [URL] = []
        urls.append(MBPersistentContainer.defaultDirectoryURL().appendingPathComponent(fileName))
        urls.append(NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(fileName))
        return Array(Set(urls.map { $0.standardizedFileURL }))
    }

    private func seedOnDiskMetadata(infoUpdate: Int?, instanceId: String?,
                                    file: StaticString = #file, line: UInt = #line) {
        let modelName = Constants.Database.mombName
        let modelURLs = [
            Bundle(for: MBDatabaseRepository.self).url(forResource: modelName, withExtension: "momd"),
            Bundle.main.url(forResource: modelName, withExtension: "momd")
        ].compactMap { $0 }
        guard
            let modelURL = modelURLs.first,
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            return XCTFail("Unable to load Core Data model \(modelName).momd", file: file, line: line)
        }

        let fm = FileManager.default

        for url in candidateStoreURLs() {
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

                let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
                let store = try psc.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: url,
                    options: nil
                )

                var md = psc.metadata(for: store)
                if let infoUpdate { md[MDKey.infoUpdate.rawValue] = infoUpdate }
                if let instanceId { md[MDKey.instanceId.rawValue] = instanceId }
                psc.setMetadata(md, for: store)

                try? psc.remove(store)

                try NSPersistentStoreCoordinator.setMetadata(
                    md,
                    forPersistentStoreOfType: NSSQLiteStoreType,
                    at: url,
                    options: nil
                )
            } catch {
                XCTFail("Failed to seed metadata at \(url): \(error)", file: file, line: line)
            }
        }

        let merged = currentMergedMetadataFromDisk()
        if let infoUpdate {
            XCTAssertEqual(merged[MDKey.infoUpdate.rawValue] as? Int, infoUpdate,
                           "Seeded on-disk infoUpdate is not visible.", file: file, line: line)
        }
        if let instanceId {
            XCTAssertEqual(merged[MDKey.instanceId.rawValue] as? String, instanceId,
                           "Seeded on-disk instanceId is not visible.", file: file, line: line)
        }
    }

    private func currentMergedMetadataFromDisk() -> [String: Any] {
        var result: [String: Any] = [:]
        for url in candidateStoreURLs() {
            if let md = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: [NSReadOnlyPersistentStoreOption: true]
            ) {
                for (k, v) in md { result[k] = v }
            }
        }
        return result
    }

    private func removeOnDiskStoresIfExist() {
        let fm = FileManager.default
        for url in candidateStoreURLs() {
            let paths = [
                url,
                url.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                url.deletingPathExtension().appendingPathExtension("sqlite-shm")
            ]
            for p in paths { try? fm.removeItem(at: p) }
        }
    }
}

// MARK: - Scenarios

extension DatabaseMetadataMigrationTests {

    func test_run_performsMigrationWhenNeeded() throws {
        let expectedInfoUpdate = 42
        let expectedInstanceId = "abc"

        seedOnDiskMetadata(infoUpdate: expectedInfoUpdate, instanceId: expectedInstanceId)
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when metadata exists and target fields are empty.")

        try migration.run()

        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be migrated from on-disk metadata.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should be migrated from on-disk metadata.")

        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Source metadata 'ApplicationInfoUpdatedVersion' should be cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Source metadata 'ApplicationInstanceId' should be cleared after migration.")

        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after successful migration.")
    }

    func test_isNeeded_false_whenTargetAlreadyHasValues_andNoMetadata() {
        storage.applicationInfoUpdateVersion = 7
        storage.applicationInstanceId = "already"

        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false when targets are filled and no metadata exists.")
    }

    func test_run_isIdempotent_viaIsNeeded() throws {
        let expectedInfoUpdate = 1
        let expectedInstanceId = "abc"

        seedOnDiskMetadata(infoUpdate: expectedInfoUpdate, instanceId: expectedInstanceId)
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true before the first run.")
        try migration.run()

        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be set on first run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should be set on first run.")
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should turn false after the first run.")
        
        migration = DatabaseMetadataMigration()
        XCTAssertFalse(migration.isNeeded, "`isNeeded` must remain false on a fresh instance after cleanup.")

        XCTAssertNoThrow(try migration.run())
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "Values must remain unchanged on a second run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "Values must remain unchanged on a second run.")

        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' should remain cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' should remain cleared after migration.")
    }

    func test_run_migratesOnlyMissingTargets_andClearsBothKeys() throws {
        let expectedInfoUpdate = 11
        let expectedInstanceId = "already-set"

        storage.applicationInstanceId = expectedInstanceId
        storage.applicationInfoUpdateVersion = nil

        seedOnDiskMetadata(infoUpdate: expectedInfoUpdate, instanceId: "from-meta")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when at least one target field is missing and metadata exists.")

        try migration.run()

        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be filled from metadata as it was missing.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should not be overwritten if already set.")

        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' should be cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' should be cleared after migration.")

        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after migration has completed.")
    }

    func test_isNeeded_false_whenNoMetadataAndTargetsEmpty() {
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false when there is nothing to migrate (no source metadata, empty targets).")
    }

    func test_run_onlyCleansMetadata_whenTargetsAlreadyFilled() throws {
        let expectedInfoUpdate = 10
        let expectedInstanceId = "already"

        storage.applicationInfoUpdateVersion = expectedInfoUpdate
        storage.applicationInstanceId = expectedInstanceId

        seedOnDiskMetadata(infoUpdate: 99, instanceId: "stale")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true to perform metadata cleanup.")

        try migration.run()

        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "Target value must not be overwritten during cleanup-only run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "Target value must not be overwritten during cleanup-only run.")

        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' must be cleared during cleanup-only run.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' must be cleared during cleanup-only run.")

        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after cleanup-only run.")
    }
}
