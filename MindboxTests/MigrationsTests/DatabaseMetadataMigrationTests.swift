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
            md[MDKey.infoUpdate.rawValue] = infoUpdate
            md[MDKey.instanceId.rawValue] = instanceId
            psc.setMetadata(md, for: store)
        } catch {
            // already failed in repoFromDI
        }
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
        // given
        seedMetadata(infoUpdate: 42, instanceId: "abc")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when metadata exists and target fields are empty.")

        // when
        try migration.run()

        // then: values are migrated into PersistenceStorage
        XCTAssertEqual(storage.applicationInfoUpdateVersion, 42, "`applicationInfoUpdateVersion` should be migrated from Core Data metadata.")
        XCTAssertEqual(storage.applicationInstanceId, "abc", "`applicationInstanceId` should be migrated from Core Data metadata.")

        // and metadata is cleared
        let meta = currentMetadata()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Source metadata 'ApplicationInfoUpdatedVersion' should be cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Source metadata 'ApplicationInstanceId' should be cleared after migration.")

        // and migration is no longer needed
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false after successful migration.")
    }

    func test_isNeeded_false_whenTargetAlreadyHasValues() {
        // given: target fields already populated
        storage.applicationInfoUpdateVersion = 7
        storage.applicationInstanceId = "already"

        // even if metadata exists, isNeeded should be false
        seedMetadata(infoUpdate: 99, instanceId: "should-not-matter")
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should be false when target fields are already populated.")

        // IMPORTANT: we do not call run() here since migration doesn't guard isNeeded internally.
        XCTAssertEqual(storage.applicationInfoUpdateVersion, 7, "`applicationInfoUpdateVersion` must remain unchanged when migration is skipped.")
        XCTAssertEqual(storage.applicationInstanceId, "already", "`applicationInstanceId` must remain unchanged when migration is skipped.")

        // Metadata remains intact on skip — that's fine.
        let meta = currentMetadata()
        XCTAssertEqual(meta[MDKey.infoUpdate.rawValue] as? Int, 99, "Metadata should remain unchanged when migration is skipped.")
        XCTAssertEqual(meta[MDKey.instanceId.rawValue] as? String, "should-not-matter", "Metadata should remain unchanged when migration is skipped.")
    }

    func test_run_isIdempotent_viaIsNeeded() throws {
        // first run
        seedMetadata(infoUpdate: 1, instanceId: "x")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true before the first run.")
        try migration.run()

        XCTAssertEqual(storage.applicationInfoUpdateVersion, 1, "`applicationInfoUpdateVersion` should be set on first run.")
        XCTAssertEqual(storage.applicationInstanceId, "x", "`applicationInstanceId` should be set on first run.")
        XCTAssertFalse(migration.isNeeded, "`isNeeded` should turn false after the first run.")

        // second run — not called (manager would skip), just assert stability
        XCTAssertEqual(storage.applicationInfoUpdateVersion, 1, "`applicationInfoUpdateVersion` should remain unchanged after migration.")
        XCTAssertEqual(storage.applicationInstanceId, "x", "`applicationInstanceId` should remain unchanged after migration.")

        // metadata is cleared
        let meta = currentMetadata()
        XCTAssertNil(meta[MDKey.infoUpdate.rawValue], "Metadata 'ApplicationInfoUpdatedVersion' should remain cleared after migration.")
        XCTAssertNil(meta[MDKey.instanceId.rawValue], "Metadata 'ApplicationInstanceId' should remain cleared after migration.")
    }

    func test_run_migratesOnlyMissingTargets_andClearsBothKeys() throws {
        // given: one target already populated
        storage.applicationInstanceId = "already-set"
        storage.applicationInfoUpdateVersion = nil

        seedMetadata(infoUpdate: 11, instanceId: "from-meta")
        XCTAssertTrue(migration.isNeeded, "`isNeeded` should be true when at least one target field is missing and metadata exists.")

        // when
        try migration.run()

        // then: fill only the missing field; do not overwrite existing ones
        XCTAssertEqual(storage.applicationInfoUpdateVersion, 11, "`applicationInfoUpdateVersion` should be filled from metadata as it was missing.")
        XCTAssertEqual(storage.applicationInstanceId, "already-set", "`applicationInstanceId` should not be overwritten if already set.")

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
}
