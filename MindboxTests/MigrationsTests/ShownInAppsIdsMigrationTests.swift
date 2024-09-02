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

final class ShownInAppsIdsMigrationTests: XCTestCase {

    private var shownInAppsIdsMigration: MigrationProtocol!
    private var migrationManager: MigrationManagerProtocol!
    private var persistenceStorageMock: PersistenceStorage!
    
    private var mbLoggerCDManager: MBLoggerCoreDataManager!
    
    private let shownInAppsIdsBeforeMigration: [String] = [
        "36920d7e-3c42-4194-9a11-b0b5c550460c",
        "37bed734-aa34-4c10-918b-873f67505d46"
    ]
    
    override func setUp() {
        super.setUp()
        shownInAppsIdsMigration = MigrationShownInAppsIds()
        
        mbLoggerCDManager = MBLoggerCoreDataManager()
        
        persistenceStorageMock = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
        persistenceStorageMock.installationDate = Date()
        persistenceStorageMock.shownInappsDictionary = nil
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

    func testShownInAppsIdsMigration() {
        migrationManager.migrate()
        
        XCTAssertNotNil(persistenceStorageMock.shownInappsDictionary, "shownInAppDictionary must NOT be nil after MigrationShownInAppIds")
        XCTAssertNil(persistenceStorageMock.shownInAppsIds, "shownInAppsIds must be nil after MigrationShownInAppIds")
        XCTAssertEqual(shownInAppsIdsBeforeMigration.count, persistenceStorageMock.shownInappsDictionary?.count, "Count must be equal")
        
        for shownInAppsIdBeforeMigration in shownInAppsIdsBeforeMigration {
            XCTContext.runActivity(named: "Check shownInAppsId \(shownInAppsIdBeforeMigration) is in shownInappsDictionary") { test in
                let contains = persistenceStorageMock.shownInappsDictionary?.keys.contains(shownInAppsIdBeforeMigration) ?? false
                XCTAssertTrue(contains, "The shownInAppsId \(shownInAppsIdBeforeMigration) should be in shownInappsDictionary")
            }
        }
        
        let defaultSetDate = Date(timeIntervalSince1970: 0)
        for (_, value) in persistenceStorageMock.shownInappsDictionary! {
            XCTAssertEqual(value, defaultSetDate)
        }
        
        let lastLog = try! mbLoggerCDManager.getLastLog()?.message
        let expectedLogMessage = "[Migrations] Migrations have been successful\n"
        XCTAssertEqual(lastLog, expectedLogMessage)
    }
    
    func testShownInAppsIdsMigrationNotNeeded() {
        let testMigrations: [MigrationProtocol] = [
            shownInAppsIdsMigration
        ]
        
        let shownInappsDictionary: [String: Date] = [
            "36920d7e-3c42-4194-9a11-b0b5c550460c": Date(),
            "37bed734-aa34-4c10-918b-873f67505d46": Date()
        ]
        
        persistenceStorageMock.shownInappsDictionary = shownInappsDictionary
        persistenceStorageMock.shownInAppsIds = nil
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 0)
        
        migrationManager.migrate()
        XCTAssertNotNil(persistenceStorageMock.shownInappsDictionary, "shownInAppDictionary must NOT be nil")
        XCTAssertNil(persistenceStorageMock.shownInAppsIds, "shownInAppsIds must be nil")
        XCTAssertEqual(shownInappsDictionary, persistenceStorageMock.shownInappsDictionary, "Must be equal")
        
        let defaultSetDateAfterMigration = Date(timeIntervalSince1970: 0)
        for (_, value) in persistenceStorageMock.shownInappsDictionary! {
            XCTAssertNotEqual(value, defaultSetDateAfterMigration)
        }
        
        let lastLog = try! mbLoggerCDManager.getLastLog()?.message
        let expectedLogMessage = "[Migrations] Migrations have been skipped\n"
        XCTAssertEqual(lastLog, expectedLogMessage)
    }
    
    func testMigrationWhenDoubleCall() {
        migrationManager.migrate()
        var lastLog = try! mbLoggerCDManager.getLastLog()?.message
        var expectedLogMessage = "[Migrations] Migrations have been successful\n"
        XCTAssertEqual(lastLog, expectedLogMessage)
        
        migrationManager.migrate()
        lastLog = try! mbLoggerCDManager.getLastLog()?.message
        expectedLogMessage = "[Migrations] Migrations have been skipped\n"
        XCTAssertEqual(lastLog, expectedLogMessage)
    }
}
