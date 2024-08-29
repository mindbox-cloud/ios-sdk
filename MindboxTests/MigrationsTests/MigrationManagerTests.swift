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
        persistenceStorageMock.shownInappsDictionary = [
            "36920d7e-3c42-4194-9a11-b0b5c550460c": Date(),
            "37bed734-aa34-4c10-918b-873f67505d46": Date()
        ]
        
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1()
        ]
        
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
    
    func testGeneralProductionMigrations() {
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock)
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == Constants.Migration.sdkVersionCode)
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT `softReset()` `persistenceStorage`")
        
        XCTAssertNotNil(persistenceStorageMock.shownInappsDictionary, "shownInAppDictionary must NOT be nil after MigrationShownInAppIds")
        XCTAssertNil(persistenceStorageMock.shownInAppsIds, "shownInAppsIds must be nil after MigrationShownInAppIds")
    }
    
    func testShowInAppsIdsMigration() {
        let testMigrations: [MigrationProtocol] = [
            MigrationShownInAppsIds()
        ]
        
        let shownInAppsIdsBeforeReset: [String] = [
            "36920d7e-3c42-4194-9a11-b0b5c550460c",
            "37bed734-aa34-4c10-918b-873f67505d46"
        ]
        
        persistenceStorageMock.shownInappsDictionary = nil
        persistenceStorageMock.shownInAppsIds = shownInAppsIdsBeforeReset
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 0)
        migrationManager.migrate()
        
        XCTAssertNotNil(persistenceStorageMock.shownInappsDictionary, "shownInAppDictionary must NOT be nil after MigrationShownInAppIds")
        XCTAssertNil(persistenceStorageMock.shownInAppsIds, "shownInAppsIds must be nil after MigrationShownInAppIds")
        XCTAssertEqual(shownInAppsIdsBeforeReset.count, persistenceStorageMock.shownInappsDictionary?.count, "Count must be equal")
        
        for shownInAppsIdBeforeReset in shownInAppsIdsBeforeReset {
            XCTContext.runActivity(named: "Check shownInAppsId \(shownInAppsIdBeforeReset) is in shownInappsDictionary") { test in
                let contains = persistenceStorageMock.shownInappsDictionary?.keys.contains(shownInAppsIdBeforeReset) ?? false
                XCTAssertTrue(contains, "The shownInAppsId \(shownInAppsIdBeforeReset) should be in shownInappsDictionary")
            }
        }
        
        let defaultSetDate = Date(timeIntervalSince1970: 0)
        
        for (_, value) in persistenceStorageMock.shownInappsDictionary! {
            XCTAssertEqual(value, defaultSetDate)
            
        }
        
        XCTAssertNotNil(persistenceStorageMock.configDownloadDate, "Must NOT softReset() persistenceStorage")
        XCTAssertNotNil(persistenceStorageMock.shownInappsDictionary, "Must NOT softReset() persistenceStorage")
        XCTAssertNotNil(persistenceStorageMock.handledlogRequestIds, "Must NOT softReset() persistenceStorage")
        let expectedUserVisitCountAfterSoftReset = 1
        XCTAssertEqual(persistenceStorageMock.userVisitCount, expectedUserVisitCountAfterSoftReset, "Must NOT softReset() persistenceStorage")
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
            TestBaseMigration_1(),
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
            TestBaseMigration_4_WithPerfomError(),
        ]
        
        let expectedSdkVersionCodeAfterMigrations = 3
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        
        XCTAssertNil(persistenceStorageMock.configDownloadDate, "Must softReset() persistenceStorage")
        XCTAssertNil(persistenceStorageMock.shownInappsDictionary, "Must softReset() persistenceStorage")
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
        XCTAssertNil(persistenceStorageMock.shownInappsDictionary, "Must softReset() persistenceStorage")
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
            TestProtocolMigration_2(persistenceStorage: persistenceStorageMock), // Used increment sdkVersionCode into `run`
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


