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

final class DatabaseMetadataMigrationTests: XCTestCase {

    private typealias MDKey = Constants.StoreMetadataKey

    private var migration: MigrationProtocol!
    private var storage: PersistenceStorage!

    override func setUp() {
        super.setUp()
        // Use real dependencies from DI (same as other tests)
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.deviceUUID = "00000000-0000-0000-0000-000000000000"
        storage.installationDate = Date()
        storage.applicationInfoUpdateVersion = nil
        storage.applicationInstanceId = nil

        migration = DatabaseMetadataMigration()
        // Precondition: DatabaseRepositoryProtocol -> MBDatabaseRepository should be available in DI
        _ = try? repoFromDI() // Fail fast if something is missing
    }

    override func tearDown() {
        migration = nil
        storage = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func repoFromDI(file: StaticString = #file, line: UInt = #line) throws -> MBDatabaseRepository {
        let repo = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        guard let casted = repo as? MBDatabaseRepository else {
            XCTFail("Expected MBDatabaseRepository from DI for DatabaseRepositoryProtocol.", file: file, line: line)
            throw NSError(domain: "test", code: -1)
        }
        return casted
    }

    private func seedMetadata(infoUpdate: Int?, instanceId: String?,
                              file: StaticString = #file, line: UInt = #line) {
        do {
            let repo = try repoFromDI(file: file, line: line)
            let psc = repo.persistentContainer.persistentStoreCoordinator
            guard let store = psc.persistentStores.first else {
                XCTFail("No persistent store attached to MBDatabaseRepository.", file: file, line: line); return
            }
            var md = psc.metadata(for: store)
            if let infoUpdate { md[MDKey.infoUpdate.rawValue] = infoUpdate }
            if let instanceId { md[MDKey.instanceId.rawValue] = instanceId }
            psc.setMetadata(md, for: store)
        } catch { }
    }

    private func currentMetadata() -> [String: Any] {
        (try? repoFromDI().persistentContainer.persistentStoreCoordinator)
            .flatMap { psc in
                guard let store = psc.persistentStores.first else { return [:] }
                return psc.metadata(for: store)
            } ?? [:]
    }
}

// MARK: - Scenarios

extension DatabaseMetadataMigrationTests {

    func test_run_performsMigrationWhenNeeded() throws {
        let expectedInfoUpdate = 42
        let expectedInstanceId = "abc"
        
        // given
        seedMetadata(infoUpdate: expectedInfoUpdate, instanceId: expectedInstanceId)
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when metadata exists and target fields are empty.")

        // when
        try migration.run()

        // then: values are migrated into PersistenceStorage
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be migrated from Core Data metadata.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should be migrated from Core Data metadata.")

        // and metadata is cleared
        let meta = currentMetadata()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Source metadata 'ApplicationInfoUpdatedVersion' should be cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Source metadata 'ApplicationInstanceId' should be cleared after migration.")

        // and migration is no longer needed
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after successful migration.")
    }

    func test_isNeeded_false_whenTargetAlreadyHasValues_andNoMetadata() {
        // given: destination already has values
        storage.applicationInfoUpdateVersion = 7
        storage.applicationInstanceId = "already"

        // IMPORTANT: do NOT seed metadata here.
        // With no source metadata, there's nothing to migrate or clean.
        XCTAssertFalse(migration.isNeeded,
                       "`isNeeded` should be false when targets are filled and no metadata exists.")
        
        // run() is intentionally not called
    }


    func test_run_isIdempotent_viaIsNeeded() throws {
        let expectedInfoUpdate = 1
        let expectedInstanceId = "abc"
        
        // first run
        seedMetadata(infoUpdate: expectedInfoUpdate, instanceId: expectedInstanceId)
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true before the first run.")
        try migration.run()

        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be set on first run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should be set on first run.")
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should turn false after the first run.")

        // second run — not called (manager would skip), just assert stability
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should remain unchanged after migration.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should remain unchanged after migration.")

        // metadata is cleared
        let meta = currentMetadata()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' should remain cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' should remain cleared after migration.")
    }

    func test_run_migratesOnlyMissingTargets_andClearsBothKeys() throws {
        let expectedInfoUpdate = 11
        let expectedInstanceId = "already-set"
        
        // given: one target already populated
        storage.applicationInstanceId = expectedInstanceId
        storage.applicationInfoUpdateVersion = nil

        seedMetadata(infoUpdate: expectedInfoUpdate, instanceId: "from-meta")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when at least one target field is missing and metadata exists.")

        // when
        try migration.run()

        // then: fill only the missing field; do not overwrite existing ones
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "`applicationInfoUpdateVersion` should be filled from metadata as it was missing.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "`applicationInstanceId` should not be overwritten if already set.")

        // but clear both metadata keys after run to avoid future re-triggers
        let meta = currentMetadata()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' should be cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' should be cleared after migration.")

        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after migration has completed.")
    }

    func test_isNeeded_false_whenNoMetadataAndTargetsEmpty() {
        // given: both targets empty and no metadata was seeded
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false when there is nothing to migrate (no source metadata, empty targets).")
        // run() is not called
    }
    
    func test_run_onlyCleansMetadata_whenTargetsAlreadyFilled() throws {
        let expectedInfoUpdate = 10
        let expectedInstanceId = "already"
        
        // given: target values are already set in the destination storage
        storage.applicationInfoUpdateVersion = expectedInfoUpdate
        storage.applicationInstanceId = expectedInstanceId

        // and stale metadata remains in the Core Data store, which should be cleaned
        seedMetadata(infoUpdate: 99, instanceId: "stale")

        // isNeeded should be true due to the cleanup branch
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true to perform metadata cleanup.")

        // when
        try migration.run()

        // then: destination values must remain unchanged
        XCTAssertEqual(storage.applicationInfoUpdateVersion, expectedInfoUpdate, "Target value must not be overwritten during cleanup-only run.")
        XCTAssertEqual(storage.applicationInstanceId, expectedInstanceId, "Target value must not be overwritten during cleanup-only run.")

        // and the metadata keys must be cleared
        let meta = currentMetadata()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' must be cleared during cleanup-only run.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' must be cleared during cleanup-only run.")

        // no subsequent migration should be needed
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after cleanup-only run.")
    }
}
