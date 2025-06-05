//
//  ShownInAppsIdsMigrationTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/2/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox
@testable import MindboxLogger

// swiftlint:disable force_try force_unwrapping

final class ShownInAppsIdsMigrationTests: XCTestCase {

    private var shownInAppsIdsMigration: MigrationProtocol!
    private var migrationManager: MigrationManagerProtocol!
    private var persistenceStorageMock: PersistenceStorage!

    private var mbLoggerCDManager: MBLoggerCoreDataManager!

    private let shownInAppsIdsBeforeMigration: [String] = [
        "36920d7e-3c42-4194-9a11-b0b5c550460c",
        "37bed734-aa34-4c10-918b-873f67505d46"
    ]

    @available(*, deprecated, message: "Suppress `deprecated` shownInAppsIds warning")
    override func setUp() {
        super.setUp()
        shownInAppsIdsMigration = MigrationShownInAppsIds()

        mbLoggerCDManager = MBLoggerCoreDataManager.shared

        persistenceStorageMock = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
        persistenceStorageMock.installationDate = Date()
        persistenceStorageMock.shownDatesByInApp = nil
        persistenceStorageMock.shownInAppsIds = shownInAppsIdsBeforeMigration

        let testMigrations: [MigrationProtocol] = [
            shownInAppsIdsMigration
        ]

        migrationManager = MigrationManager(
            persistenceStorage: persistenceStorageMock,
            migrations: testMigrations,
            sdkVersionCode: 0
        )
    }

    override func tearDown() {
        shownInAppsIdsMigration = nil
        mbLoggerCDManager = nil
        migrationManager = nil
        persistenceStorageMock = nil
        super.tearDown()
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInAppsIds warning")
    func test_ShownInAppsIdsMigration_withIsNeededTrue_shouldPerformSuccessfully() throws {
        // MARK: - Do not change shownInappsDictionary in this class. Is should be unchanged because we have migration. 
        try mbLoggerCDManager.deleteAll()

        let migrationExpectation = XCTestExpectation(description: "Migration completed")
        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertNotNil(self.persistenceStorageMock.shownInappsDictionary, "shownInAppDictionary must NOT be nil after MigrationShownInAppIds")
            XCTAssertNil(self.persistenceStorageMock.shownInAppsIds, "shownInAppsIds must be nil after MigrationShownInAppIds")
            XCTAssertEqual(self.shownInAppsIdsBeforeMigration.count, self.persistenceStorageMock.shownInappsDictionary?.count, "Count must be equal")

            for shownInAppsIdBeforeMigration in self.shownInAppsIdsBeforeMigration {
                XCTContext.runActivity(named: "Check shownInAppsId \(shownInAppsIdBeforeMigration) is in shownInappsDictionary") { _ in
                    let contains = self.persistenceStorageMock.shownInappsDictionary?.keys.contains(shownInAppsIdBeforeMigration) ?? false
                    XCTAssertTrue(contains, "The shownInAppsId \(shownInAppsIdBeforeMigration) should be in shownInappsDictionary")
                }
            }

            migrationExpectation.fulfill()
        }

        wait(for: [migrationExpectation], timeout: 5)

        let lastLog = try mbLoggerCDManager.getLastLog()
        let expectedLogMessage = "[Migrations] Migrations have been successful\n"
        XCTAssertEqual(lastLog?.message, expectedLogMessage)
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInAppsIds warning")
    func test_ShownInAppsIdsMigration_withIsNeededFalse_shouldHaveBeenSkipped() throws {
        try mbLoggerCDManager.deleteAll()

        let migrationExpectation = XCTestExpectation(description: "Migration completed")

        let testMigrations: [MigrationProtocol] = [
            shownInAppsIdsMigration
        ]

        let shownDatesByInApp: [String: [Date]] = [
            "1": [Date()],
            "2": [Date()]
        ]

        persistenceStorageMock.shownDatesByInApp = shownDatesByInApp
        persistenceStorageMock.shownInAppsIds = nil

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 0)

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

    func test_ShownInAppsIdsMigration_withDoubleCall_shouldBePerformedOnlyTheFirstTime() throws {
        try mbLoggerCDManager.deleteAll()

        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        let migrationExpectation = XCTestExpectation(description: "Migration completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            migrationExpectation.fulfill()
        }

        wait(for: [migrationExpectation], timeout: 5)

        var lastLog = try! mbLoggerCDManager.getLastLog()?.message
        var expectedLogMessage = "[Migrations] Migrations have been successful\n"
        XCTAssertEqual(lastLog, expectedLogMessage)

        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        let migrationExpectationTwo = XCTestExpectation(description: "Migration 2 completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            migrationExpectationTwo.fulfill()
        }

        wait(for: [migrationExpectationTwo], timeout: 5)
        lastLog = try! mbLoggerCDManager.getLastLog()?.message
        expectedLogMessage = "[Migrations] Migrations have been skipped\n"
        XCTAssertEqual(lastLog, expectedLogMessage)
    }
}
