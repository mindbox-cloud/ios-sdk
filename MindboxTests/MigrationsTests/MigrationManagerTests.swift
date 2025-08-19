//
//  MigrationManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 7/30/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class MigrationManagerTests: XCTestCase {

    private var migrationManager: MigrationManagerProtocol!
    private var persistenceStorageMock: PersistenceStorage!

    override func setUp() {
        super.setUp()
        persistenceStorageMock = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
        persistenceStorageMock.installationDate = Date()
        persistenceStorageMock.configDownloadDate = Date()
        persistenceStorageMock.userVisitCount = 1
        persistenceStorageMock.handledlogRequestIds = ["37db8697-ace9-4d1f-99b6-7e303d6c874f"]
        persistenceStorageMock.shownDatesByInApp = [
            "1": [Date()],
            "2": [Date()]
        ]

        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1()
        ]
        
        setUpForRemoveBackgroundTaskDataMigration()

        migrationManager = MigrationManager(
            persistenceStorage: persistenceStorageMock,
            migrations: testMigrations,
            sdkVersionCode: 1
        )
    }

    override func tearDown() {
        migrationManager = nil
        persistenceStorageMock = nil
        super.tearDown()
    }

    @available(*, deprecated, message: "Suppress `deprecated` shownInAppsIds warning")
    func testProductionMigrations() { // Check list of migrations in MigrationManager - self.migration
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock)
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == Constants.Migration.sdkVersionCode)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
        XCTAssertNil(persistenceStorageMock.shownInappsDictionary, "shownInappsDictionary must NOT be nil after MigrationShownInAppIds")
        XCTAssertNotNil(persistenceStorageMock.shownDatesByInApp, "shownDatesByInApp must NOT be nil after MigrationShownInAppIds")
        XCTAssertNil(persistenceStorageMock.shownInAppsIds, "shownInAppsIds must be nil after MigrationShownInAppIds")
        
        XCTAssertForRemoveBackgroundTaskDataMigration()
    }

    func testPerformTestMigrationsButFirstInstallationAndSkipMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1()
        ]

        persistenceStorageMock.installationDate = nil

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 1)
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 1)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }
}

// MARK: - Additional functions for production migrations

extension MigrationManagerTests {
    func XCTAssertForRemoveBackgroundTaskDataMigration() {
        XCTAssertNil(MBPersistenceStorage.defaults.value(forKey: "backgroundExecution"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func setUpForRemoveBackgroundTaskDataMigration() {
        let key = "backgroundExecution"
        let userDefaultsSuiteName = "MigrationManagerTests"
        
        let userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        MBPersistenceStorage.defaults = userDefaults
        
        userDefaults.set(Data(), forKey: key)
        
        try? createDummyFile()
    }
    
    private var documentsURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var fileURL: URL {
        let plistName = "BackgroundExecution.plist"
        return documentsURL.appendingPathComponent(plistName)
    }
    
    private func createDummyFile() throws {
        // Просто создаём пустой файл в Documents
        FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
    }
}

// MARK: - Base Migrations Tests

extension MigrationManagerTests {

    func testPerformOneTestBaseMigrationFromSetUp() {
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 1)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }

    func testPerformTwoTestBaseMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1(),
            TestBaseMigration_2()
        ]

        let expectedSdkVersionCodeAfterMigrations = 2

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }

    func testPerformThreeTestBaseMigrationsWithOneIsNeededEqualFalse() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1(),
            TestBaseMigration_2(),
            TestBaseMigration_3_IsNeeded_False() // IsNeeded == false -> No auto increment in BaseMigration
        ]

        let expectedSdkVersionCodeAfterMigrations = 2

        migrationManager = MigrationManager(
            persistenceStorage: persistenceStorageMock,
            migrations: testMigrations,
            sdkVersionCode: expectedSdkVersionCodeAfterMigrations
        )

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }

    func testSortPerformThreeTestMigrationsThatAreDecalredInARandomOrder() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_2(),
            TestBaseMigration_3_IsNeeded_False(),
            TestBaseMigration_1()
        ]

        let expectedSdkVersionCodeAfterMigrations = 2

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }

    func testPerformTestBaseMigrationsWhenOneThrowError() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_2(),
            TestBaseMigration_1(),
            TestBaseMigration_4_WithPerfomError()
        ]

        let expectedSdkVersionCodeAfterMigrations = 3

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)

        XCTAssertNil(persistenceStorageMock.configDownloadDate, "Must softReset() persistenceStorage")
        XCTAssertNil(persistenceStorageMock.shownDatesByInApp, "Must softReset() persistenceStorage")
        XCTAssertNil(persistenceStorageMock.handledlogRequestIds, "Must softReset() persistenceStorage")
        let expectedUserVisitCountAfterSoftReset = 0
        XCTAssertEqual(persistenceStorageMock.userVisitCount, expectedUserVisitCountAfterSoftReset, "Must softReset() persistenceStorage")
    }
}

// MARK: - Protocol Migrations Tests

extension MigrationManagerTests {

    func testPerformOneTestProtocolMigration() {
        let testMigrations: [MigrationProtocol] = [
            TestProtocolMigration_1()
        ]

        let expectedSdkVersionCodeAfterMigrations = 0

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }

    func testPerformTwoTestProtocolMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestProtocolMigration_1(),
            TestProtocolMigration_2(persistenceStorage: persistenceStorageMock) // Used increment sdkVersionCode into `run`
        ]

        let expectedSdkVersionCodeAfterMigrations = 1

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }

    func testPerformThreeTestProtocolMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestProtocolMigration_1(),
            TestProtocolMigration_2(persistenceStorage: persistenceStorageMock), // Used increment sdkVersionCode into `run`
            TestProtocolMigration_3(persistenceStorage: persistenceStorageMock) // Throw error into `run`
        ]

        let expectedSdkVersionCodeAfterMigrations = 2

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)

        XCTAssertNil(persistenceStorageMock.configDownloadDate, "Must softReset() persistenceStorage")
        XCTAssertNil(persistenceStorageMock.shownDatesByInApp, "Must softReset() persistenceStorage")
        XCTAssertNil(persistenceStorageMock.handledlogRequestIds, "Must softReset() persistenceStorage")
        let expectedUserVisitCountAfterSoftReset = 0
        XCTAssertEqual(persistenceStorageMock.userVisitCount, expectedUserVisitCountAfterSoftReset, "Must softReset() persistenceStorage")
    }
}

// MARK: - Mixed Migrations Tests

extension MigrationManagerTests {

    func testPerformMixedTestMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1(), // Auto Increment sdkVersionCode
            TestBaseMigration_2(), // Auto Increment sdkVersionCode
            TestProtocolMigration_1(),
            TestProtocolMigration_2(persistenceStorage: persistenceStorageMock) // Used increment sdkVersionCode into `run`
        ]

        let expectedSdkVersionCodeAfterMigrations = 3

        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)

        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
    }
}
