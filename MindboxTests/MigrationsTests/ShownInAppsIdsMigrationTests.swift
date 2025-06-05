//
//  ShownInAppsIdsMigrationTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/2/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try force_unwrapping

final class ShownInAppsIdsMigrationTests: XCTestCase {

    // MARK: Test data

    /// Legacy IDs that must be migrated into the dictionary.
    private let legacyIds = [
        "36920d7e-3c42-4194-9a11-b0b5c550460c",
        "37bed734-aa34-4c10-918b-873f67505d46"
    ]

    // MARK: SUT & collaborators

    private var migration: MigrationProtocol!
    private var storage: PersistenceStorage!

        persistenceStorageMock = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
        persistenceStorageMock.installationDate = Date()
        persistenceStorageMock.shownDatesByInApp = nil
        persistenceStorageMock.shownInAppsIds = shownInAppsIdsBeforeMigration

    @available(*, deprecated,
               message: "Suppress `deprecated` shownInAppsIds warning")
    override func setUp() {
        super.setUp()

        // real migration object
        migration = MigrationShownInAppsIds()

        // persistence stub from DI container
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.deviceUUID = "00000000-0000-0000-0000-000000000000"
        storage.installationDate      = Date()
        storage.shownInappsDictionary = nil
        storage.shownInAppsIds        = legacyIds      // legacy state
    }

    override func tearDown() {
        migration = nil
        storage   = nil
        super.tearDown()
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInAppsIds warning")
    func test_ShownInAppsIdsMigration_withIsNeededTrue_shouldPerformSuccessfully() throws {
        // MARK: - Do not change shownInappsDictionary in this class. Is should be unchanged because we have migration. 
        try mbLoggerCDManager.deleteAll()

    /// Ensures the legacy array is removed and each id
    /// appears in `shownInappsDictionary`.
    @available(*, deprecated,
               message: "Suppress `deprecated` shownInAppsIds warning")
    private func assertIdsWereMigrated(file: StaticString = #file, line: UInt = #line) {
        XCTAssertNil(storage.shownInAppsIds,
                     "Array must be nil after migration",
                     file: file, line: line)

        guard let dict = storage.shownInappsDictionary else {
            XCTFail("Dictionary must exist", file: file, line: line); return
        }

        XCTAssertEqual(dict.count, legacyIds.count,
                       "All elements must be migrated",
                       file: file, line: line)

        legacyIds.forEach { id in
            XCTAssertTrue(dict.keys.contains(id),
                          "Missing migrated key \(id)",
                          file: file, line: line)
        }
    }
}

// MARK: - Scenarios

@available(*, deprecated,
           message: "Suppress `deprecated` shownInAppsIds warning")
extension ShownInAppsIdsMigrationTests {

    /// When `isNeeded == true`, `run()` performs the migration.
    func test_run_performsMigrationWhenNeeded() throws {
        // pre-condition
        XCTAssertTrue(migration.isNeeded)

        let shownDatesByInApp: [String: [Date]] = [
            "1": [Date()],
            "2": [Date()]
        ]

        persistenceStorageMock.shownDatesByInApp = shownDatesByInApp
        persistenceStorageMock.shownInAppsIds = nil

    /// If data is already in the new format, `isNeeded` is false and
    /// `run()` becomes a no-op.
    func test_run_skipsWhenAlreadyMigrated() throws {
        // given – simulate post-migration state
        storage.shownInappsDictionary = legacyIds.reduce(into: [:]) { $0[$1] = Date() }
        storage.shownInAppsIds = nil
        XCTAssertFalse(migration.isNeeded)

        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertNotNil(self.persistenceStorageMock.shownDatesByInApp, "shownInAppShowDatesDictionary must NOT be nil")
            XCTAssertNil(self.persistenceStorageMock.shownInAppsIds, "shownInAppsIds must be nil")
            XCTAssertEqual(shownDatesByInApp, self.persistenceStorageMock.shownDatesByInApp, "Must be equal")

            for (_, value) in self.persistenceStorageMock.shownDatesByInApp! {
                XCTAssertEqual(value.count, 1, "Each in-app should have exactly one show date")
            }

            migrationExpectation.fulfill()
        }

        wait(for: [migrationExpectation], timeout: 5)

        let lastLog = try mbLoggerCDManager.getLastLog()
        let expectedLogMessage = "[Migrations] Migrations have been skipped\n"
        XCTAssertEqual(lastLog?.message, expectedLogMessage)
    }

    /// Two consecutive runs: the first migrates, the second is silently skipped
    /// (idempotence).
    func test_run_isIdempotent() throws {
        try migration.run()
        assertIdsWereMigrated()

        // second run – no changes, no throws
        XCTAssertNoThrow(try migration.run())
        XCTAssertEqual(storage.shownInappsDictionary?.count, legacyIds.count)
        XCTAssertNil(storage.shownInAppsIds)
    }
}
