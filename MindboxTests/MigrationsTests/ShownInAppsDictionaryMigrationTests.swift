//
//  ShownInAppsDictionaryMigrationTests.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.06.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox
@testable import MindboxLogger

final class ShownInAppsDictionaryMigrationTests: XCTestCase {

    private var shownInAppsDictionaryMigration: MigrationProtocol!
    private var migrationManager: MigrationManagerProtocol!
    private var persistenceStorageMock: PersistenceStorage!

    private var mbLoggerCDManager: MBLoggerCoreDataManager!

    private let shownInAppsDictionaryBeforeMigration: [String: Date] = [
        "36920d7e-3c42-4194-9a11-b0b5c550460c": Date(),
        "37bed734-aa34-4c10-918b-873f67505d46": Date()
    ]

    @available(*, deprecated, message: "Suppress `deprecated` shownInappsDictionary warning")
    override func setUp() {
        super.setUp()
        shownInAppsDictionaryMigration = MigrationShownInAppsDictionary()

        mbLoggerCDManager = MBLoggerCoreDataManager.shared

        persistenceStorageMock = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
        persistenceStorageMock.installationDate = Date()
        persistenceStorageMock.shownInappsShowDatesDictionary = nil
        persistenceStorageMock.shownInappsDictionary = shownInAppsDictionaryBeforeMigration
        persistenceStorageMock.versionCodeForMigration = 1

        let testMigrations: [MigrationProtocol] = [
            shownInAppsDictionaryMigration
        ]

        migrationManager = MigrationManager(
            persistenceStorage: persistenceStorageMock,
            migrations: testMigrations,
            sdkVersionCode: 1
        )
    }

    override func tearDown() {
        shownInAppsDictionaryMigration = nil
        mbLoggerCDManager = nil
        migrationManager = nil
        persistenceStorageMock = nil
        super.tearDown()
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInappsDictionary warning")
    func test_ShownInAppsDictionaryMigration_withIsNeededTrue_shouldPerformSuccessfully() throws {
        try mbLoggerCDManager.deleteAll()

        let migrationExpectation = XCTestExpectation(description: "Migration completed")
        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertNotNil(self.persistenceStorageMock.shownInappsShowDatesDictionary)
            XCTAssertNil(self.persistenceStorageMock.shownInappsDictionary)
            XCTAssertEqual(self.shownInAppsDictionaryBeforeMigration.count, 
                          self.persistenceStorageMock.shownInappsShowDatesDictionary?.count)

            guard let migratedDictionary = self.persistenceStorageMock.shownInappsShowDatesDictionary else {
                XCTFail("Migrated dictionary should not be nil")
                return
            }

            for (id, date) in self.shownInAppsDictionaryBeforeMigration {
                XCTContext.runActivity(named: "Check shownInAppsId \(id) is in shownInappsShowDatesDictionary") { _ in
                    guard let dates = migratedDictionary[id] else {
                        XCTFail("The shownInAppsId \(id) should be in shownInappsShowDatesDictionary")
                        return
                    }
                    XCTAssertEqual(dates.count, 1, "Each in-app should have exactly one show date")
                    XCTAssertEqual(dates.first, date, "The show date should match the original date")
                }
            }

            migrationExpectation.fulfill()
        }

        wait(for: [migrationExpectation], timeout: 5)

        let lastLog = try mbLoggerCDManager.getLastLog()
        let expectedLogMessage = "[Migrations] Migrations have been successful\n"
        XCTAssertEqual(lastLog?.message, expectedLogMessage)
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInappsDictionary warning")
    func test_ShownInAppsDictionaryMigration_withIsNeededFalse_shouldHaveBeenSkipped() throws {
        try mbLoggerCDManager.deleteAll()

        let migrationExpectation = XCTestExpectation(description: "Migration completed")

        let testMigrations: [MigrationProtocol] = [
            shownInAppsDictionaryMigration
        ]

        let shownInappsShowDatesDictionary: [String: [Date]] = [
            "1": [Date()],
            "2": [Date()]
        ]

        persistenceStorageMock.shownInappsShowDatesDictionary = shownInappsShowDatesDictionary
        persistenceStorageMock.shownInappsDictionary = nil

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                          migrations: testMigrations, 
                                          sdkVersionCode: 1)

        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertNotNil(self.persistenceStorageMock.shownInappsShowDatesDictionary)
            XCTAssertNil(self.persistenceStorageMock.shownInappsDictionary)
            XCTAssertEqual(shownInappsShowDatesDictionary, 
                          self.persistenceStorageMock.shownInappsShowDatesDictionary)

            guard let migratedDictionary = self.persistenceStorageMock.shownInappsShowDatesDictionary else {
                XCTFail("Migrated dictionary should not be nil")
                return
            }

            for (_, dates) in migratedDictionary {
                XCTAssertEqual(dates.count, 1, "Each in-app should have exactly one show date")
            }

            migrationExpectation.fulfill()
        }

        wait(for: [migrationExpectation], timeout: 5)

        let lastLog = try mbLoggerCDManager.getLastLog()
        let expectedLogMessage = "[Migrations] Migrations have been skipped\n"
        XCTAssertEqual(lastLog?.message, expectedLogMessage)
    }

    func test_ShownInAppsDictionaryMigration_withDoubleCall_shouldBePerformedOnlyTheFirstTime() throws {
        try mbLoggerCDManager.deleteAll()

        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        let migrationExpectation = XCTestExpectation(description: "Migration completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            migrationExpectation.fulfill()
        }

        wait(for: [migrationExpectation], timeout: 5)

        let firstLog = try mbLoggerCDManager.getLastLog()
        let firstExpectedMessage = "[Migrations] Migrations have been successful\n"
        XCTAssertEqual(firstLog?.message, firstExpectedMessage)

        migrationManager.migrate()
        mbLoggerCDManager.debugWriteBufferToCD()

        let migrationExpectationTwo = XCTestExpectation(description: "Migration 2 completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            migrationExpectationTwo.fulfill()
        }

        wait(for: [migrationExpectationTwo], timeout: 5)
        
        let secondLog = try mbLoggerCDManager.getLastLog()
        let secondExpectedMessage = "[Migrations] Migrations have been skipped\n"
        XCTAssertEqual(secondLog?.message, secondExpectedMessage)
    }
} 
