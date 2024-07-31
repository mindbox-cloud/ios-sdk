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
        
        let testMigrations: [MigrationProtocol] = [
            TestMigration1()
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock, migrations: testMigrations, localVersionCode: 1)
    }
    
    override func tearDown() {
        migrationManager = nil
        persistenceStorageMock = nil
        super.tearDown()
    }
    
    func testProductionMigrations() {
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock)
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == MigrationConstants.sdkVersionCode)
    }

    func testPerformOneTestMigration() {
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 1)
    }
    
    func testPerformTwoTestMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestMigration1(),
            TestMigration2()
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock, migrations: testMigrations, localVersionCode: 2)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 2)
    }
    
    // Тест, когда одна из миграций false. Но при этом мы не завязываемся на MigrationConstant. Может там какое-то условие в одной из миграций без неё будет
    func testPerformThreeTestMigrationsWithOneIsNeededEqualFalse() {
        let testMigrations: [MigrationProtocol] = [
            TestMigration1(),
            TestMigration2(),
            TestMigration3_IsNeeded_False()
        ]
        
        let expectedCountSucceededMigrations = 2
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock, migrations: testMigrations, localVersionCode: 2)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 2)
    }
    
    func testPerformThreeTestMigrationsThatAreDecalredInARandomOrder() {
        let testMigrations: [MigrationProtocol] = [
            TestMigration2(),
            TestMigration3_IsNeeded_False(),
            TestMigration1(),
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock, migrations: testMigrations, localVersionCode: 2)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 2)
    }
    
    func testPerformFourTestMigrationsWithError() {
        let testMigrations: [MigrationProtocol] = [
            TestMigration2(),
            TestMigration3_IsNeeded_False(),
            TestMigration1(),
            TestMigration4_WithPerfomError(),
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock, migrations: testMigrations, localVersionCode: 3)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 3)
        XCTAssertNil(persistenceStorageMock.deviceUUID, "Must reset() persistenceStorage")
    }
}


fileprivate final class TestMigration1: BaseMigration {
    override var description: String {
        "TestMigration number 1"
    }
    
    override var isNeeded: Bool {
        true
    }
    
    override var version: Int {
        1
    }
    
    override func performMigration() throws {
        // Do some code
    }
}

fileprivate final class TestMigration2: BaseMigration {
    override var description: String {
        "TestMigration number 2"
    }
    
    override var isNeeded: Bool {
        true
    }
    
    override var version: Int {
        2
    }
    
    override func performMigration() throws {
        // Do some code
    }
}

fileprivate final class TestMigration3_IsNeeded_False: BaseMigration {
    override var description: String {
        "TestMigration number 3. isNeeded == false"
    }
    
    override var isNeeded: Bool {
        false
    }
    
    override var version: Int {
        3
    }
    
    override func performMigration() throws {
        // Do some code
    }
}

fileprivate final class TestMigration4_WithPerfomError: BaseMigration {
    override var description: String {
        "TestMigration number 4. perfromMigration throw error"
    }
    
    override var isNeeded: Bool {
        true
    }
    
    override var version: Int {
        4
    }
    
    override func performMigration() throws {
        // Do some code
        throw NSError(domain: "com.sdk.migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid version for migration"])
    }
}
