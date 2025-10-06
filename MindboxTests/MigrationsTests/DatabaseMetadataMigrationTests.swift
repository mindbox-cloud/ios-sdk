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
@testable import MindboxLogger // MBPersistentContainer

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

    /// Full list of candidate store paths — must mirror the logic in the migration.
    private func candidateStoreURLs() -> [URL] {
        let fileName = "\(Constants.Database.mombName).sqlite"
        var urls: [URL] = []
        urls.append(MBPersistentContainer.defaultDirectoryURL().appendingPathComponent(fileName))
        urls.append(NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(fileName))
        // Deduplicate
        return Array(Set(urls.map { $0.standardizedFileURL }))
    }

    /// Creates a SQLite store, writes metadata, and ensures it is flushed to disk.
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
                // Ensure parent directory exists.
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

                let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
                let store = try psc.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: url,
                    options: nil
                )

                // Ensure parent directory exists.
                var md = psc.metadata(for: store)
                if let infoUpdate { md[MDKey.infoUpdate.rawValue] = infoUpdate }
                if let instanceId { md[MDKey.instanceId.rawValue] = instanceId }
                psc.setMetadata(md, for: store)

                // Detach the store to flush metadata to disk.
                try? psc.remove(store)

                // As an extra safety measure, persist the same metadata via the class API (writes to the file header).
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

        // Sanity check: verify the keys are visible from at least one candidate.
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

    /// Reads metadata from all candidates and merges it (last write wins).
    private func currentMergedMetadataFromDisk() -> [String: Any] {
        var result: [String: Any] = [:]
        for url in candidateStoreURLs() {
            if let md = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: [NSReadOnlyPersistentStoreOption: true]
            ) {
                // Merge — allow later sources to overwrite keys.
                for (k, v) in md { result[k] = v }
            }
        }
        return result
    }

    /// Removes .sqlite and the related -wal/-shm files for all candidates.
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

        // given — seed metadata on disk (no live repository required)
        seedOnDiskMetadata(infoUpdate: expectedInfoUpdate, instanceId: expectedInstanceId)
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when metadata exists and target fields are empty.")

        // when
        try migration.run()

        // then — values were copied into PersistenceStorage
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be migrated from on-disk metadata.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should be migrated from on-disk metadata.")

        // and metadata got cleared across all store files
        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Source metadata 'ApplicationInfoUpdatedVersion' should be cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Source metadata 'ApplicationInstanceId' should be cleared after migration.")

        // no subsequent migration should be needed
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after successful migration.")
    }

    func test_isNeeded_false_whenTargetAlreadyHasValues_andNoMetadata() {
        // given: destination values are already set
        storage.applicationInfoUpdateVersion = 7
        storage.applicationInstanceId = "already"

        // do not seed any metadata — disk is empty
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false when targets are filled and no metadata exists.")
    }

    func test_run_isIdempotent_viaIsNeeded() throws {
        let expectedInfoUpdate = 1
        let expectedInstanceId = "abc"

        // first run
        seedOnDiskMetadata(infoUpdate: expectedInfoUpdate, instanceId: expectedInstanceId)
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true before the first run.")
        try migration.run()

        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be set on first run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should be set on first run.")
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should turn false after the first run.")
        
        // simulate a fresh app launch (no cached state inside the migration)
        migration = DatabaseMetadataMigration()
        XCTAssertFalse(migration.isNeeded, "`isNeeded` must remain false on a fresh instance after cleanup.")

        // second run: calling run() again must be a no-op
        XCTAssertNoThrow(try migration.run())
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "Values must remain unchanged on a second run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "Values must remain unchanged on a second run.")

        // metadata remains cleared
        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' should remain cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' should remain cleared after migration.")
    }

    func test_run_migratesOnlyMissingTargets_andClearsBothKeys() throws {
        let expectedInfoUpdate = 11
        let expectedInstanceId = "already-set"

        // given: one target is already populated
        storage.applicationInstanceId = expectedInstanceId
        storage.applicationInfoUpdateVersion = nil

        seedOnDiskMetadata(infoUpdate: expectedInfoUpdate, instanceId: "from-meta")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when at least one target field is missing and metadata exists.")

        // when
        try migration.run()

        // then: fill only the missing field; do not overwrite existing values
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be filled from metadata as it was missing.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should not be overwritten if already set.")

        // clear both metadata keys to avoid future re-triggers
        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' should be cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' should be cleared after migration.")

        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after migration has completed.")
    }

    func test_isNeeded_false_whenNoMetadataAndTargetsEmpty() {
        // given: both targets are empty and no metadata was seeded
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false when there is nothing to migrate (no source metadata, empty targets).")
    }

    func test_run_onlyCleansMetadata_whenTargetsAlreadyFilled() throws {
        let expectedInfoUpdate = 10
        let expectedInstanceId = "already"

        // given: destination values are already set
        storage.applicationInfoUpdateVersion = expectedInfoUpdate
        storage.applicationInstanceId = expectedInstanceId

        // and stale metadata still exists on disk — it should be cleaned up
        seedOnDiskMetadata(infoUpdate: 99, instanceId: "stale")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true to perform metadata cleanup.")

        // when
        try migration.run()

        // then: destination values must remain unchanged
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "Target value must not be overwritten during cleanup-only run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "Target value must not be overwritten during cleanup-only run.")

        // and the metadata keys must be removed across all stores
        let meta = currentMergedMetadataFromDisk()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' must be cleared during cleanup-only run.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' must be cleared during cleanup-only run.")

        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after cleanup-only run.")
    }
}
